local M = {}
local utils = require("codock.utils")

-- slot -> terminal buffer
local slots = {}
-- terminal buffer -> slot
local slot_of = {}

-- Whether the slot header above terminal windows is enabled.
local show_header = true

---Normalize a terminal slot number to a positive integer.
---@param slot integer
---@return integer
local function normalize_slot(slot)
	slot = tonumber(slot) or 1
	if slot < 1 then
		slot = 1
	end
	return math.floor(slot)
end

---Move a codock terminal window to the latest output.
---
---Neovim only tails terminal output while the terminal cursor is on the last
---line. Leaving terminal-mode early can leave the inactive window cursor at an
---older line, so put it back on the current last line before focus moves away.
---@param win integer terminal window
---@param buf integer terminal buffer
function M.scroll_to_bottom(win, buf)
	if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(buf)
	pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
end

---Return all windows in the current tabpage displaying a buffer.
---@param buf integer
---@return integer[]
function M.find_windows(buf)
	local wins = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
			table.insert(wins, win)
		end
	end
	return wins
end

---Get the terminal buffer registered for a slot.
---@param slot integer
---@return integer|nil buf
function M.get_slot(slot)
	slot = normalize_slot(slot)
	local buf = slots[slot]
	if buf and utils.is_codock_terminal(buf) then
		return buf
	end
	slots[slot] = nil
	if buf then
		slot_of[buf] = nil
	end
	return nil
end

---Register a terminal buffer for a slot.
---@param slot integer
---@param buf integer
function M.set_slot(slot, buf)
	local normalized = normalize_slot(slot)
	slots[normalized] = buf
	slot_of[buf] = normalized
end

---Return the slot registered for a terminal buffer, if any.
---@param buf integer terminal buffer
---@return integer|nil slot
function M.slot_for(buf)
	return slot_of[buf]
end

---Enable or disable the slot header shown above terminal windows.
---@param enabled boolean
function M.enable_header(enabled)
	show_header = enabled
end

---Apply the slot header to a window.
---
---The header is a one-line winbar showing the slot number of the window's
---terminal buffer. It requires Neovim 0.11+ (`winbar`); on older versions
---this is a no-op. Setting an empty value only clears the window-local
---option, so a user-configured global winbar keeps working.
---@param win integer window
function M.apply_header(win)
	if vim.fn.has("nvim-0.11") ~= 1 or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local slot = slot_of[buf]
	if not slot or not utils.is_codock_terminal(buf) then
		return
	end

	local header = "%#CodockHeader#\u{f1cc}  " .. slot
	vim.wo[win].winbar = show_header and header or ""
end

---Create a vertical split and prepare it to display a codock terminal.
---@param width integer terminal width
---@return integer win
local function open_split(width)
	vim.cmd("vsplit")
	local win = vim.api.nvim_get_current_win()

	-- Always set winfixwidth to prevent automatic width adjustments (like
	-- ctrl+w =) but allow manual width adjustments (like ctrl+w > / ctrl+w <).
	vim.api.nvim_win_set_width(win, width)
	vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
	vim.w[win].codock_terminal = true

	return win
end

---Open a new codock terminal in a vertical split.
---@param width integer terminal width
---@param codock_cmd string command to run
---@param augroup integer autocmd group
---@param slot integer terminal slot
---@return integer buf terminal buffer
function M.create(width, codock_cmd, augroup, slot)
	local win = open_split(width)

	-- Open terminal and run codock command from the project root (or the
	-- current working directory when git is not available)
	local project_root = utils.find_project_root()
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_win_set_buf(win, buf)
	vim.fn.jobstart(codock_cmd, { term = true, cwd = project_root })

	-- Set buffer options to hide from buffer tab
	vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
	vim.b[buf].codock_terminal = true
	utils.remember_codock_terminal(buf)
	M.set_slot(slot, buf)
	M.apply_header(win)

	-- Set up terminal key mappings for window navigation
	local term_opts = { buffer = buf, silent = true }
	vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", term_opts)
	vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", term_opts)
	vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", term_opts)
	vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", term_opts)

	-- Set up autocmd to enter terminal mode when entering the codock terminal
	-- buffer. This intentionally checks the buffer instead of the creating
	-- window so it keeps working after a hidden terminal is shown again.
	vim.api.nvim_create_autocmd("WinEnter", {
		group = augroup,
		buffer = buf,
		callback = function()
			M.apply_header(vim.api.nvim_get_current_win())
			if vim.api.nvim_get_current_buf() == buf then
				vim.cmd("startinsert")
			end
		end,
	})

	-- Keep Neovim's native terminal tailing active after a window loses focus.
	vim.api.nvim_create_autocmd({ "TermLeave", "WinLeave" }, {
		group = augroup,
		buffer = buf,
		callback = function()
			for _, win in ipairs(M.find_windows(buf)) do
				M.scroll_to_bottom(win, buf)
			end
		end,
	})

	-- Enter terminal mode immediately
	vim.cmd("startinsert")

	return buf
end

---Show an existing codock terminal buffer in a vertical split.
---@param buf integer terminal buffer
---@param width integer terminal width
---@return integer win terminal window
function M.show(buf, width)
	local win = open_split(width)
	vim.api.nvim_win_set_buf(win, buf)
	utils.remember_codock_terminal(buf)
	M.apply_header(win)
	vim.cmd("startinsert")
	return win
end

---Hide all windows displaying a codock terminal buffer.
---
---Closing a window does not wipe the buffer, so the terminal process keeps
---running and can be shown again later with the same buffer contents.
---@param buf integer terminal buffer
function M.hide(buf)
	local wins = M.find_windows(buf)
	local visible_wins = {}
	for _, win in ipairs(wins) do
		if vim.api.nvim_win_is_valid(win) then
			table.insert(visible_wins, win)
		end
	end

	if #visible_wins == 0 then
		return
	end

	-- Neovim refuses to close the last window in a tabpage. If every window
	-- shows this terminal buffer, replace one with a scratch buffer and close
	-- the rest so the terminal buffer still becomes hidden.
	local tab_wins = vim.api.nvim_tabpage_list_wins(0)
	local has_other_window = false
	for _, win in ipairs(tab_wins) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) ~= buf then
			has_other_window = true
			break
		end
	end

	if not has_other_window then
		for i = 2, #visible_wins do
			pcall(vim.api.nvim_win_close, visible_wins[i], true)
		end

		local last_win = visible_wins[1]
		if vim.api.nvim_win_is_valid(last_win) then
			local scratch = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_option_value("buflisted", false, { buf = scratch })
			vim.api.nvim_win_set_buf(last_win, scratch)
		end
		return
	end

	for _, win in ipairs(visible_wins) do
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
end

---Toggle a codock terminal slot.
---
---If the slot has a visible window, hide it. If it has a hidden buffer, show
---it. If it has no terminal yet, create one.
---@param slot integer terminal slot (1-based)
---@param width integer terminal width
---@param codock_cmd string command to run
---@param augroup integer autocmd group
function M.toggle(slot, width, codock_cmd, augroup)
	slot = normalize_slot(slot)
	local buf = M.get_slot(slot)

	if buf then
		if #M.find_windows(buf) > 0 then
			M.hide(buf)
		else
			M.show(buf, width)
		end
	else
		M.create(width, codock_cmd, augroup, slot)
	end
end

---Send text to the most recently focused codock terminal.
---@param text string text to send
---@return boolean sent
function M.send(text)
	local buf = utils.find_codock_terminal()
	if not buf then
		return false
	end

	-- Focus the terminal window when it is visible so the user sees the
	-- result and the terminal is tracked as the most recently focused one.
	local wins = M.find_windows(buf)
	if #wins > 0 then
		vim.api.nvim_set_current_win(wins[1])
	end

	local channel = vim.bo[buf].channel
	if not channel then
		return false
	end

	return pcall(vim.api.nvim_chan_send, channel, text)
end

---Send text to an existing codock terminal or open the first slot first.
---@param text string text to send
---@param width integer terminal width
---@param codock_cmd string command to run
---@param augroup integer autocmd group
function M.send_or_open(text, width, codock_cmd, augroup)
	local buf = utils.find_codock_terminal()
	if not buf then
		M.toggle(1, width, codock_cmd, augroup)
		vim.defer_fn(function()
			M.send(text)
		end, 3000)
		return
	end

	-- If the most recently focused terminal is hidden, show it again before
	-- sending so the user can see the result.
	if #M.find_windows(buf) == 0 then
		M.show(buf, width)
	end

	M.send(text)
end

---Resize all visible codock terminal windows.
---@param width integer terminal width
---@return integer resized_count number of codock terminal windows resized
function M.resize_all(width)
	local resized_count = 0

	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
			if vim.api.nvim_win_is_valid(win) then
				local buf = vim.api.nvim_win_get_buf(win)
				if utils.is_codock_terminal(buf) then
					vim.api.nvim_win_set_width(win, width)
					resized_count = resized_count + 1
				end
			end
		end
	end

	return resized_count
end

return M
