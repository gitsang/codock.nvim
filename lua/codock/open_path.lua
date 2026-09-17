local M = {}

local utils = require("codock.utils")

---Open the file path under the mouse in an editor window.
---
---The file replaces the buffer shown in that window, like a normal `:edit`,
---but is left listed so the buffer line can switch back to the previous file.
---
---Returns `false` when the click should keep its native behavior, which lets
---the caller replay the mouse event. That is the case for clicks outside a
---codock terminal, clicks on the window bar, and clicks that do not land on a
---file that exists.
---
---The file is opened without moving focus away from the terminal, so the CLI
---session keeps receiving input.
---@return boolean handled
function M.open_at_mouse()
	local mouse = vim.fn.getmousepos()
	-- Clicks on the window bar or the status line report line 0.
	if mouse.line < 1 or mouse.column < 1 then
		return false
	end

	local ok, term_buf = pcall(vim.api.nvim_win_get_buf, mouse.winid)
	if not ok or not utils.is_codock_terminal(term_buf) then
		return false
	end

	local line = vim.api.nvim_buf_get_lines(term_buf, mouse.line - 1, mouse.line, false)[1]
	if not line then
		return false
	end

	local base_cwd = utils.get_terminal_cwd_for(term_buf)

	-- Resolving is also what lets the parser recognize file names containing
	-- characters that are otherwise ambiguous (spaces, parentheses, `#`).
	local function resolve(path)
		return utils.resolve_file_path(path, base_cwd)
	end

	local clicked = utils.parse_file_path_at(line, mouse.column, resolve)
	if not clicked then
		return false
	end

	local abs_path = resolve(clicked.path)
	if not abs_path then
		return false
	end

	local target_win = utils.find_file_window(mouse.winid)
	if not target_win then
		return false
	end

	if not utils.open_file_at(target_win, abs_path, clicked.line, clicked.col) then
		return false
	end

	return true
end

return M
