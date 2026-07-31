local M = {}
local utils = require("codock.utils")

---Format visual coordinates as a file position suffix.
---@param position CodockVisualPosition
---@return string
local function format_visual_position(position)
	if position.mode == "V" then
		if position.start_line == position.end_line then
			return string.format("L%d", position.start_line)
		end
		return string.format("L%d-L%d", position.start_line, position.end_line)
	end

	if position.mode == "v" then
		if position.start_line == position.end_line then
			return string.format("L%d:C%d-C%d", position.start_line, position.start_col, position.end_col)
		end
		return string.format(
			"L%d-L%d:C%d-C%d",
			position.start_line,
			position.end_line,
			position.start_col,
			position.end_col
		)
	end

	if position.mode == "\22" then
		if position.start_line == position.end_line and position.start_col == position.end_col then
			return string.format("L%dC%d", position.start_line, position.start_col)
		end
		return string.format(
			"L%dC%d-L%dC%d",
			position.start_line,
			position.start_col,
			position.end_line,
			position.end_col
		)
	end

	return string.format("L%d", position.start_line)
end

---Copy a formatted file position to registers and optionally the system clipboard.
---@param copy_to_clipboard boolean
---@param prefix? string
---@return string
local function copy_visual_pos(copy_to_clipboard, prefix)
	local visual_position = format_visual_position(utils.get_visual_position())
	local result = (prefix or "") .. utils.get_current_file() .. ":" .. visual_position

	vim.fn.setreg('"', result)
	vim.fn.setreg("0", result)

	local clipboard_success = false
	if copy_to_clipboard then
		local success = pcall(function()
			vim.fn.setreg("+", result)
		end)
		clipboard_success = success and vim.fn.getreg("+") == result
	end

	if copy_to_clipboard and clipboard_success then
		vim.notify("Copied to clipboard: " .. result, vim.log.levels.INFO)
	elseif copy_to_clipboard then
		vim.notify("Copied to register (clipboard unavailable): " .. result, vim.log.levels.WARN)
	else
		vim.notify("Copied to register: " .. result .. " (paste with p)", vim.log.levels.INFO)
	end

	return result
end

---@param copy_to_clipboard boolean
---@param prefix string
---@param source_win? integer
---@return string
local function copy_from_window(copy_to_clipboard, prefix, source_win)
	if source_win and vim.api.nvim_win_is_valid(source_win) then
		return vim.api.nvim_win_call(source_win, function()
			return copy_visual_pos(copy_to_clipboard, prefix)
		end)
	end
	return copy_visual_pos(copy_to_clipboard, prefix)
end

---@param callback fun(prefix: string)
local function input_prefix(callback)
	vim.ui.input({
		prompt = "File position prefix: ",
		default = "",
	}, function(prefix)
		if prefix ~= nil then
			callback(prefix)
		end
	end)
end

---@class CodockFilePositionOptions
---@field copy_to_clipboard boolean
---@field send fun(text: string)

---@class CodockFilePositionFeature
---@field actions CodockAction[]
---@field register_commands fun()

---@param options CodockFilePositionOptions
---@return CodockFilePositionFeature
function M.create(options)
	local actions = {
		{
			name = "Yank file position",
			description = "Copy the current file position with an optional prefix",
			execute = function()
				local source_win = vim.api.nvim_get_current_win()
				input_prefix(function(prefix)
					copy_from_window(options.copy_to_clipboard, prefix, source_win)
				end)
			end,
		},
		{
			name = "Paste file position",
			description = "Copy and send the current file position with an optional prefix",
			execute = function(context)
				local source_win = vim.api.nvim_get_current_win()
				input_prefix(function(prefix)
					local file_position = copy_from_window(options.copy_to_clipboard, prefix, source_win)
					context.send(file_position .. " ")
				end)
			end,
		},
	}

	local function register_commands()
		vim.api.nvim_create_user_command("CodockFilePosPaste", function(cmd_opts)
			local file_position = copy_visual_pos(options.copy_to_clipboard, cmd_opts.args)
			options.send(file_position .. " ")
		end, { nargs = "?", range = true })
		vim.api.nvim_create_user_command("CodockFilePosYank", function(cmd_opts)
			copy_visual_pos(options.copy_to_clipboard, cmd_opts.args)
		end, { nargs = "?", range = true })
		vim.api.nvim_create_user_command("CodockFilePos", function(cmd_opts)
			local file_position = copy_visual_pos(options.copy_to_clipboard, cmd_opts.args)
			options.send(file_position .. " ")
		end, { nargs = "?", range = true })
	end

	return {
		actions = actions,
		register_commands = register_commands,
	}
end

return M
