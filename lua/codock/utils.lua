local M = {}

---Get visual selection range
---@return integer start_line, integer end_line
function M.get_visual_range()
	local visual_mode = vim.fn.visualmode()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")

	if visual_mode == "" then
		-- Not in visual mode, use current line
		start_line = vim.fn.line(".")
		end_line = start_line
	end

	return start_line, end_line
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
		local prefix = term_cwd:sub(-1) == "/" and term_cwd or (term_cwd .. "/")
		if abs_path:sub(1, #prefix) == prefix then
			return abs_path:sub(#prefix + 1)
		end
		return abs_path
	end

	return vim.fn.fnamemodify(abs_path, ":.")
end

return M
