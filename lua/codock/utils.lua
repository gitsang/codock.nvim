local M = {}

---@class CodockVisualPosition
---@field mode string
---@field start_line integer
---@field start_col integer
---@field end_line integer
---@field end_col integer

---Get the current visual selection coordinates or cursor position.
---@return CodockVisualPosition
function M.get_visual_position()
	local mode = vim.fn.visualmode()
	if mode == "" then
		local line = vim.fn.line(".")
		local col = vim.fn.col(".")
		return {
			mode = mode,
			start_line = line,
			start_col = col,
			end_line = line,
			end_col = col,
		}
	end

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line, start_col = start_pos[2], start_pos[3]
	local end_line, end_col = end_pos[2], end_pos[3]

	if start_line > end_line or (start_line == end_line and start_col > end_col) then
		start_line, end_line = end_line, start_line
		start_col, end_col = end_col, start_col
	end

	return {
		mode = mode,
		start_line = start_line,
		start_col = start_col,
		end_line = end_line,
		end_col = end_col,
	}
end

---Get visual selection range.
---@return integer start_line, integer end_line
function M.get_visual_range()
	local position = M.get_visual_position()
	return position.start_line, position.end_line
end

---Find codock terminal buffer
---@return integer|nil bufnr
function M.find_codock_terminal()
	local bufs = vim.api.nvim_list_bufs()
	for _, buf in ipairs(bufs) do
		if vim.api.nvim_buf_is_valid(buf) then
			local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
			if buftype == "terminal" and vim.b[buf].codock_terminal then
				return buf
			end
		end
	end
	return nil
end

---Get the working directory of the codock terminal process
---@return string|nil cwd or nil if unavailable
function M.get_terminal_cwd()
	local term_buf = M.find_codock_terminal()
	if not term_buf then
		return nil
	end
	local pid = vim.b[term_buf].terminal_job_pid
	if not pid then
		return nil
	end
	-- On Linux, resolve /proc/<pid>/cwd symlink
	local proc_cwd = "/proc/" .. tostring(pid) .. "/cwd"
	local ok, result = pcall(vim.fn.resolve, proc_cwd)
	if ok and result and result ~= "" and result ~= proc_cwd then
		return result
	end
	return nil
end

---Get a path relative to a base directory, including paths outside the base.
---@param base_path string
---@param target_path string
---@return string
local function relative_path(base_path, target_path)
	local base_parts = vim.split(base_path, "/", { plain = true, trimempty = true })
	local target_parts = vim.split(target_path, "/", { plain = true, trimempty = true })
	local common_parts = 0

	while base_parts[common_parts + 1] == target_parts[common_parts + 1] and base_parts[common_parts + 1] ~= nil do
		common_parts = common_parts + 1
	end

	local result_parts = {}
	for _ = common_parts + 1, #base_parts do
		table.insert(result_parts, "..")
	end
	for index = common_parts + 1, #target_parts do
		table.insert(result_parts, target_parts[index])
	end

	return #result_parts > 0 and table.concat(result_parts, "/") or "."
end

---Get current file path relative to terminal cwd (falls back to Neovim cwd)
---@return string file_path
function M.get_current_file()
	local buf = vim.api.nvim_get_current_buf()
	local abs_path = vim.api.nvim_buf_get_name(buf)
	if abs_path == "" then
		return ""
	end

	local term_cwd = M.get_terminal_cwd()
	if term_cwd then
		return relative_path(term_cwd, abs_path)
	end

	return vim.fn.fnamemodify(abs_path, ":.")
end

---Get visual selection text
---@return string
function M.get_visual_selection_text()
	local position = M.get_visual_position()
	local bufnr = vim.api.nvim_get_current_buf()

	if position.mode == "" then
		return vim.api.nvim_get_current_line()
	end

	local start_line = position.start_line
	local start_col = position.start_col
	local end_line = position.end_line
	local end_col = position.end_col
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	if #lines == 0 then
		return ""
	end

	if position.mode == "V" then
		return table.concat(lines, "\n")
	end

	if position.mode == "\022" then
		for i, line in ipairs(lines) do
			lines[i] = string.sub(line, start_col, end_col)
		end

		return table.concat(lines, "\n")
	end

	if #lines == 1 then
		return string.sub(lines[1], start_col, end_col)
	end

	lines[1] = string.sub(lines[1], start_col)
	lines[#lines] = string.sub(lines[#lines], 1, end_col)

	return table.concat(lines, "\n")
end

return M
