local M = {}
local utils = require("codock.utils")

---Move a codock terminal window to the latest output.
---
---Neovim only tails terminal output while the terminal cursor is on the last
---line. Leaving terminal-mode early can leave the inactive window cursor at an
---older line, so put it back on the current last line before focus moves away.
---@param win integer terminal window
---@param buf integer terminal buffer
local function scroll_terminal_to_bottom(win, buf)
	if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(buf)
	pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
end

---Get visual position string from current buffer and selection
---@return string position_string
local function get_visual_pos()
	local result = ""

	-- Check if we have a range (from visual selection)
	local visual_mode = vim.fn.visualmode()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")
	local start_col = vim.fn.col("'<")
	local end_col = vim.fn.col("'>")

	if visual_mode == "V" then
		-- VISUAL LINE mode
		if start_line == end_line then
			result = string.format("L%d", start_line)
		else
			result = string.format("L%d-L%d", start_line, end_line)
		end
	elseif visual_mode == "v" then
		-- VISUAL mode (character-wise)
		if start_line == end_line then
			-- Single line in VISUAL mode
			result = string.format("L%d:C%d-C%d", start_line, start_col, end_col)
		else
			-- Multiple lines in VISUAL mode
			result = string.format("L%d-L%d:C%d-C%d", start_line, end_line, start_col, end_col)
		end
	elseif visual_mode == "\22" then
		-- BLOCK mode
		if start_line == end_line and start_col == end_col then
			-- Single character in BLOCK mode
			result = string.format("L%dC%d", start_line, start_col)
		else
			-- Multiple characters in BLOCK mode
			result = string.format("L%dC%d-L%dC%d", start_line, start_col, end_line, end_col)
		end
	else
		-- Not in visual mode, just copy current line
		local current_line = vim.fn.line(".")
		result = string.format("L%d", current_line)
	end

	return result
end

---Send text to codock terminal
---@param text string text to send
local function send_to_terminal(text)
	local buf = utils.find_codock_terminal()
	if not buf then
		return false
	end

	-- Find the window containing this buffer
	local wins = vim.api.nvim_list_wins()
	for _, win in ipairs(wins) do
		if vim.api.nvim_win_is_valid(win) then
			if vim.api.nvim_win_get_buf(win) == buf then
				-- Focus the terminal window
				vim.api.nvim_set_current_win(win)
				-- Send text to terminal
				vim.api.nvim_chan_send(vim.bo[buf].channel, text)
				return true
			end
		end
	end
	return false
end

---Copy visual position to system clipboard and send to codock terminal
---@param copy_to_clipboard? boolean whether to copy to system clipboard
local function copy_visual_pos(copy_to_clipboard)
	local current_file = utils.get_current_file()
	local visual_pos = get_visual_pos()
	local result = current_file .. ":" .. visual_pos

	-- Always copy to unnamed register (works without system clipboard)
	vim.fn.setreg('"', result)
	vim.fn.setreg("0", result)

	-- Copy to system clipboard only if enabled
	local clipboard_success = false
	if copy_to_clipboard then
		local success = pcall(function()
			vim.fn.setreg("+", result)
		end)

		if success then
			-- Verify of content was actually copied
			local clipboard_content = vim.fn.getreg("+")
			if clipboard_content == result then
				clipboard_success = true
			end
		end
	end

	-- Show appropriate notification
	if copy_to_clipboard and clipboard_success then
		vim.notify("Copied to clipboard: " .. result, vim.log.levels.INFO)
	elseif copy_to_clipboard then
		vim.notify("Copied to register (clipboard unavailable): " .. result, vim.log.levels.WARN)
	else
		vim.notify("Copied to register: " .. result .. " (paste with p)", vim.log.levels.INFO)
	end

	-- Return data for terminal sending
	return current_file, visual_pos
end

---Open codock terminal in vertical split
---@param width integer terminal width
---@param codock_cmd string command to run
---@param fixed_width boolean whether to fix window width
local function open_codock_terminal(width, codock_cmd, fixed_width, augroup)
	-- Create a vertical split
	vim.cmd("vsplit")
	local win = vim.api.nvim_get_current_win()

	-- Set window width
	-- Always set winfixwidth to prevent automatic width adjustments (like ctrl+w =)
	-- but allow manual width adjustments (like ctrl+w > / ctrl+w <)
	vim.api.nvim_win_set_width(win, width)
	vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
	vim.w[win].codock_terminal = true

	-- Open terminal and run codock command
	vim.cmd("terminal " .. codock_cmd)

	-- Set buffer options to hide from buffer tab
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
	vim.b[buf].codock_terminal = true

	-- Set up terminal key mappings for window navigation
	local term_opts = { buffer = buf, silent = true }
	vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", term_opts)
	vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", term_opts)
	vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", term_opts)
	vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", term_opts)

	-- Set up autocmd to enter terminal mode when entering codock terminal window
	vim.api.nvim_create_autocmd("WinEnter", {
		group = augroup,
		buffer = buf,
		callback = function()
			if vim.api.nvim_get_current_win() == win then
				vim.cmd("startinsert")
			end
		end,
	})

	-- Keep Neovim's native terminal tailing active after the window loses focus.
	vim.api.nvim_create_autocmd({ "TermLeave", "WinLeave" }, {
		group = augroup,
		buffer = buf,
		callback = function()
			scroll_terminal_to_bottom(win, buf)
		end,
	})

	-- Enter terminal mode immediately
	vim.cmd("startinsert")
end

---@class CodockAction
---@field name string
---@field description? string
---@field prompts string|fun():string

---@class CodockOptions
---@field width? integer
---@field codock_cmd? string
---@field fixed_width? boolean
---@field copy_to_clipboard? boolean
---@field actions? CodockAction[]

---Handle CodockFilePos command
---@param copy_to_clipboard boolean whether to copy to clipboard
---@param width integer terminal width
---@param codock_cmd string command to run
---@param fixed_width boolean whether to fix window width
local function handle_codock_filepos(copy_to_clipboard, width, codock_cmd, fixed_width, augroup)
	local current_file, visual_pos = copy_visual_pos(copy_to_clipboard)

	-- Check if codock terminal exists
	if utils.find_codock_terminal() then
		-- Send to existing terminal: @file, enter, :pos
		send_to_terminal(current_file .. ":" .. visual_pos .. " ")
	else
		-- Open codock terminal first, then send
		open_codock_terminal(width, codock_cmd, fixed_width, augroup)
		-- Wait a bit for terminal to be ready, then send
		vim.defer_fn(function()
			send_to_terminal(current_file .. ":" .. visual_pos .. " ")
		end, 3000)
	end
end

---Handle CodockActions command
---@param opts CodockOptions configuration options
---@param width integer terminal width
---@param codock_cmd string command to run
---@param fixed_width boolean whether to fix window width
local function handle_codock_actions(opts, width, codock_cmd, fixed_width, augroup)
	if not opts.actions or #opts.actions == 0 then
		vim.notify("No actions configured", vim.log.levels.WARN)
		return
	end

	-- Prepare items for selection
	local items = {}
	for _, action in ipairs(opts.actions) do
		table.insert(items, {
			name = action.name,
			description = action.description or "",
			action = action,
		})
	end

	-- Show popup selector
	vim.ui.select(items, {
		prompt = "Select action:",
		format_item = function(item)
			if item.description ~= "" then
				return item.name .. " - " .. item.description
			else
				return item.name
			end
		end,
	}, function(selected)
		if not selected then
			return
		end

		-- Get the prompt
		local prompt = ""
		if type(selected.action.prompts) == "function" then
			prompt = selected.action.prompts()
		else
			prompt = selected.action.prompts
		end

		-- Ensure terminal exists
		if not utils.find_codock_terminal() then
			open_codock_terminal(width, codock_cmd, fixed_width, augroup)
			vim.defer_fn(function()
				send_to_terminal(prompt)
			end, 3000)
		else
			send_to_terminal(prompt)
		end
	end)
end

---Setup function for codock.nvim
---@param opts? CodockOptions
function M.setup(opts)
	opts = opts or {}
	local width = opts.width or 80
	local codock_cmd = opts.codock_cmd or "codock"
	local fixed_width = opts.fixed_width or false
	local copy_to_clipboard = opts.copy_to_clipboard ~= false -- default to true
	local augroup = vim.api.nvim_create_augroup("codock_nvim", { clear = true })

	-- Initialize actions array if not provided
	if not opts.actions then
		opts.actions = {}
	end

	-- Load default actions and insert them at the beginning
	local default_actions = require("codock.actions.default").get_default_actions()
	for i = #default_actions, 1, -1 do
		table.insert(opts.actions, 1, default_actions[i])
	end

	-- Create Codock command (supports optional argument: :Codock [cmd])
	vim.api.nvim_create_user_command("Codock", function(cmd_opts)
		local cmd = cmd_opts.args
		if cmd == "" then
			cmd = codock_cmd
		end
		open_codock_terminal(width, cmd, fixed_width, augroup)
	end, { nargs = "?" })
	vim.api.nvim_create_user_command("CodockActions", function()
		handle_codock_actions(opts, width, codock_cmd, fixed_width, augroup)
	end, { range = true })
	vim.api.nvim_create_user_command("CodockFilePos", function()
		handle_codock_filepos(copy_to_clipboard, width, codock_cmd, fixed_width, augroup)
	end, { range = true })

	-- Add autocommand to maintain width on window resize (only if fixed_width is enabled)
	if fixed_width then
		vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
			group = augroup,
			callback = function()
				-- Get all windows
				local wins = vim.api.nvim_list_wins()

				-- If WinResized event, only check the resized windows
				if vim.v.event and vim.v.event.windows then
					wins = vim.v.event.windows or {}
				end

				for _, winid in ipairs(wins) do
					if vim.api.nvim_win_is_valid(winid) then
						if vim.w[winid].codock_terminal then
							if vim.api.nvim_win_get_width(winid) ~= width then
								vim.api.nvim_win_set_width(winid, width)
							end
						end
					end
				end
			end,
		})
	end
end

return M
