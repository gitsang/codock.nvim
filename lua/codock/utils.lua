local M = {}

-- Visual selection

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

-- Terminal

local last_codock_terminal_buf = nil

---Check whether a buffer is a codock terminal.
---@param buf integer
---@return boolean
function M.is_codock_terminal(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end

	local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
	if buftype ~= "terminal" or not vim.b[buf].codock_terminal then
		return false
	end

	return true
end

---Remember a codock terminal buffer as the most recently focused one.
---@param buf integer
function M.remember_codock_terminal(buf)
	if M.is_codock_terminal(buf) then
		last_codock_terminal_buf = buf
	end
end

---Remember the current buffer if it is a codock terminal.
function M.track_current_codock_terminal()
	M.remember_codock_terminal(vim.api.nvim_get_current_buf())
end

---Find the most recently focused codock terminal buffer.
---Falls back to the first codock terminal buffer when the tracked buffer is gone.
---@return integer|nil bufnr
function M.find_codock_terminal()
	if last_codock_terminal_buf and M.is_codock_terminal(last_codock_terminal_buf) then
		return last_codock_terminal_buf
	end

	last_codock_terminal_buf = nil

	local bufs = vim.api.nvim_list_bufs()
	for _, buf in ipairs(bufs) do
		if M.is_codock_terminal(buf) then
			last_codock_terminal_buf = buf
			return buf
		end
	end

	return nil
end

---Get the working directory of a codock terminal process.
---
---The process may have changed directory since it started, so the `/proc`
---symlink is preferred (Linux only) and the directory recorded in the
---`term://` buffer name is only a fallback.
---@param buf integer terminal buffer
---@return string|nil cwd or nil if unavailable
function M.get_terminal_cwd_for(buf)
	if not M.is_codock_terminal(buf) then
		return nil
	end

	local pid = vim.b[buf].terminal_job_pid
	if pid then
		local proc_cwd = "/proc/" .. tostring(pid) .. "/cwd"
		local ok, result = pcall(vim.fn.resolve, proc_cwd)
		if ok and result and result ~= "" and result ~= proc_cwd then
			return result
		end
	end

	-- Fall back to the directory the terminal was started in.
	local cwd = vim.api.nvim_buf_get_name(buf):match("^term://(.-)//")
	if cwd and cwd ~= "" then
		return cwd
	end

	return nil
end

---Get the working directory of the most recently focused codock terminal.
---@return string|nil cwd or nil if unavailable
function M.get_terminal_cwd()
	local term_buf = M.find_codock_terminal()
	if not term_buf then
		return nil
	end
	return M.get_terminal_cwd_for(term_buf)
end

-- Paths

---Find the project root via git, falling back to the current working directory.
---@return string root
function M.find_project_root()
	local cwd = vim.fn.getcwd()
	local ok, result = pcall(vim.fn.system, { "git", "-C", cwd, "rev-parse", "--show-toplevel" })
	if ok and type(result) == "string" then
		local root = result:gsub("[\r\n]+$", "")
		if root ~= "" and vim.v.shell_error == 0 then
			return root
		end
	end
	return cwd
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

-- Characters that may start or continue a file path printed to the terminal.
-- Bytes above 127 are included so that non-ASCII (for example CJK) file names
-- are matched as well.
local PATH_CHARS = "%w%._~/@%+%-\128-\255"
-- A path-like token, including any `:line` / `:col` suffix. Lua patterns cannot
-- make a capture group optional, so the suffix is split off afterwards.
local PATH_TOKEN_PATTERN = "([" .. PATH_CHARS .. "][" .. PATH_CHARS .. ":]*)"
-- Punctuation that usually belongs to the surrounding prose, not to the path.
local TRAILING_PUNCTUATION_PATTERN = "[%.,;:%)%]}>\"']+$"

---@class CodockClickedPath
---@field path string path as printed in the terminal
---@field line integer|nil 1-based line from a `:line` suffix
---@field col integer|nil 1-based column from a `:col` suffix

---Split a trailing `:line` or `:line:col` suffix off a path token.
---@param token string
---@return string path
---@return integer|nil line
---@return integer|nil col
local function split_position_suffix(token)
	local first, second = token:match(":(%d+):(%d+)$")
	if first then
		local suffix_len = #first + #second + 2
		return token:sub(1, #token - suffix_len), tonumber(first), tonumber(second)
	end

	local line = token:match(":(%d+)$")
	if line then
		return token:sub(1, #token - #line - 1), tonumber(line), nil
	end

	return token, nil, nil
end

---Find the file path under a byte column in a line of terminal output.
---
---A `:line` and `:col` suffix is part of the match, so a click anywhere on
---`path/to/file.lua:12:3` opens the file at that position. Trailing prose
---punctuation (as in `see path/to/file.lua.`) is not part of the path.
---@param line string
---@param col integer 1-based byte column of the click
---@return CodockClickedPath|nil
function M.parse_file_path_at(line, col)
	local init = 1
	while true do
		local start_index, end_index, token = line:find(PATH_TOKEN_PATTERN, init)
		if not start_index then
			return nil
		end

		-- Drop surrounding prose punctuation before looking for the suffix, so
		-- that a trailing `.` cannot hide a `:line:col` part of the token.
		local trimmed = token:gsub(TRAILING_PUNCTUATION_PATTERN, "")
		if trimmed ~= "" then
			local path, line_number, col_number = split_position_suffix(trimmed)
			local path_end = start_index + #path - 1
			local token_end = start_index + #trimmed - 1

			if path ~= "" then
				local in_path = col >= start_index and col <= path_end
				local in_suffix = line_number ~= nil and col > path_end and col <= token_end
				if in_path or in_suffix then
					return {
						path = path,
						line = line_number,
						col = col_number,
					}
				end
			end
		end

		init = end_index + 1
	end
end

---Resolve a path printed in terminal output to an existing file.
---
---Relative paths are resolved against the terminal working directory first
---and the Neovim working directory second. A leading `@` (as used by
---`:CodockFilePosPaste`) is ignored, and directories are not resolved.
---@param candidate string path as printed in the terminal
---@param base_cwd string|nil terminal working directory
---@return string|nil abs_path absolute path of an existing file
function M.resolve_file_path(candidate, base_cwd)
	local path = candidate:gsub("^@", "")
	if path == "" then
		return nil
	end

	local candidates = {}
	if path:sub(1, 1) == "/" or path:sub(1, 1) == "~" then
		table.insert(candidates, vim.fn.expand(path))
	else
		if base_cwd and base_cwd ~= "" then
			table.insert(candidates, base_cwd .. "/" .. path)
		end
		local cwd = vim.fn.getcwd()
		if cwd ~= "" then
			table.insert(candidates, cwd .. "/" .. path)
		end
	end

	for _, candidate_path in ipairs(candidates) do
		local abs_path = vim.fn.fnamemodify(candidate_path, ":p")
		local stat = vim.uv.fs_stat(abs_path)
		if stat and stat.type == "file" then
			return abs_path
		end
	end

	return nil
end

---Find the editor window that should display files opened from a terminal.
---
---The window closest to the terminal on its left side wins, which matches the
---usual codock layout. As a fallback the left-most editor window in the
---tabpage is used. Terminal windows (codock or not) and floating windows are
---never returned, so a terminal buffer is never replaced by an opened file.
---@param terminal_win integer|nil window the request came from
---@return integer|nil win
function M.find_file_window(terminal_win)
	local candidates = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
			local buf = vim.api.nvim_win_get_buf(win)
			local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
			if buftype ~= "terminal" then
				table.insert(candidates, win)
			end
		end
	end

	if #candidates == 0 then
		return nil
	end

	-- Prefer the window directly left of the terminal.
	if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
		local terminal_col = vim.api.nvim_win_get_position(terminal_win)[2]
		local best, best_col = nil, nil
		for _, win in ipairs(candidates) do
			local col = vim.api.nvim_win_get_position(win)[2]
			if col < terminal_col and (best_col == nil or col > best_col) then
				best, best_col = win, col
			end
		end
		if best then
			return best
		end
	end

	-- Otherwise use the left-most window, breaking ties by screen row.
	local best, best_col, best_row = nil, nil, nil
	for _, win in ipairs(candidates) do
		local row, col = vim.api.nvim_win_get_position(win)[1], vim.api.nvim_win_get_position(win)[2]
		if best_col == nil or col < best_col or (col == best_col and row < best_row) then
			best, best_col, best_row = win, col, row
		end
	end

	return best
end

---Open a file at a position in a window without changing the current window.
---
---The buffer is loaded through `bufadd()`/`bufload()` so filetype detection
---and other `BufRead` hooks still run, while `nvim_win_set_buf()` keeps the
---currently focused window (usually the terminal) untouched.
---@param win integer window to display the file in
---@param abs_path string absolute path of an existing file
---@param line integer|nil 1-based line to jump to
---@param col integer|nil 1-based byte column to jump to
---@return boolean opened
function M.open_file_at(win, abs_path, line, col)
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end

	local buf = vim.fn.bufadd(abs_path)
	vim.fn.bufload(buf)
	if not vim.api.nvim_buf_is_loaded(buf) then
		return false
	end

	vim.api.nvim_win_set_buf(win, buf)

	local line_count = vim.api.nvim_buf_line_count(buf)
	local target_line = math.max(math.min(line or 1, line_count), 1)
	local line_text = vim.api.nvim_buf_get_lines(buf, target_line - 1, target_line, false)[1] or ""
	local target_col = 0
	if col and col > 0 then
		target_col = math.min(col - 1, math.max(#line_text - 1, 0))
	end

	pcall(vim.api.nvim_win_set_cursor, win, { target_line, target_col })
	-- Center the line so the file is not scrolled to an arbitrary offset.
	pcall(vim.api.nvim_win_call, win, function()
		vim.cmd("normal! zz")
	end)

	return true
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

return M
