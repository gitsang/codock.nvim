local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

local function fail(message)
	error(message, 0)
end

local function assert_true(condition, message)
	if not condition then
		fail(message)
	end
end

---Count the scroll hooks registered for a terminal buffer.
---@param buf integer
---@return integer
local function scroll_hook_count(buf)
	local count = 0
	for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = "codock_nvim" })) do
		local is_scroll_event = autocmd.event == "WinLeave" or autocmd.event == "TermLeave"
		-- `buffer` is the buffer number the autocmd is local to.
		if is_scroll_event and autocmd.buffer == buf then
			count = count + 1
		end
	end
	return count
end

---Open a long-running terminal in slot 1 and return its window and buffer.
---@return integer win, integer buf
local function open_terminal()
	vim.cmd("Codock")
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()
	vim.cmd("stopinsert")
	assert_true(vim.bo[buf].buftype == "terminal", "Codock did not open a terminal buffer")
	return win, buf
end

---Return a window in the current tabpage that does not show the terminal.
---@param term_win integer
---@return integer|nil
local function find_other_win(term_win)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= term_win then
			return win
		end
	end
	return nil
end

---Scroll the terminal to the first line and leave the window.
---@param term_win integer
---@param other_win integer
local function scroll_to_top_and_leave(term_win, other_win)
	vim.api.nvim_win_set_cursor(term_win, { 1, 0 })
	vim.api.nvim_set_current_win(other_win)
end

---Run a CLI that prints two bursts separated by a pause, so output arrives
---while the terminal is unfocused.
local cmd = "sh -c 'for i in $(seq 1 30); do echo first-$i; sleep 0.01; done; "
	.. "sleep 1; for i in $(seq 1 30); do echo second-$i; sleep 0.01; done; sleep 5'"

require("codock").setup({
	width = 40,
	codock_cmd = cmd,
	copy_to_clipboard = false,
})

vim.cmd("enew")
local term_win, term_buf = open_terminal()
local other_win = find_other_win(term_win)
assert_true(other_win ~= nil, "Expected a source window next to the terminal")

-- The scroll hooks are registered by default, once per buffer.
assert_true(
	scroll_hook_count(term_buf) == 2,
	"Expected the WinLeave and TermLeave scroll hooks by default"
)

-- Default behavior: scrolling up and leaving the window jumps back to the
-- bottom, so the terminal keeps following output.
scroll_to_top_and_leave(term_win, other_win)
assert_true(
	vim.api.nvim_win_get_cursor(term_win)[1] == vim.api.nvim_buf_line_count(term_buf),
	"Auto scroll should have moved the cursor to the last line"
)
assert_true(scroll_hook_count(term_buf) == 2, "Sleeping must not duplicate the scroll hooks")

-- :CodockScroll off removes the hooks from terminals that already exist.
vim.cmd("CodockScroll off")
assert_true(scroll_hook_count(term_buf) == 0, "CodockScroll off should remove the scroll hooks")
assert_true(
	require("codock.terminal").follow_output_enabled() == false,
	"Follow output should be off"
)

local lines_before = vim.api.nvim_buf_line_count(term_buf)
scroll_to_top_and_leave(term_win, other_win)
assert_true(
	vim.api.nvim_win_get_cursor(term_win)[1] == 1,
	"CodockScroll off should leave the viewport where the user put it"
)

-- Output printed while unfocused must still reach the buffer; only the
-- viewport stops following it.
local got_second_burst = vim.wait(3000, function()
	if not vim.api.nvim_buf_is_valid(term_buf) then
		return false
	end
	local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
	return table.concat(lines):find("second%-30") ~= nil
end, 20)
assert_true(got_second_burst, "The terminal should keep receiving output while unfocused")
assert_true(
	vim.api.nvim_buf_line_count(term_buf) > lines_before,
	"Unfocused output should still be appended to the buffer"
)
assert_true(
	vim.api.nvim_win_get_cursor(term_win)[1] == 1,
	"CodockScroll off should keep the cursor on the first line while output arrives"
)

-- New terminals created while the behavior is off get no hooks either.
vim.cmd("CodockScroll off")
vim.api.nvim_set_current_win(other_win)
vim.cmd("2Codock")
local term2_buf = vim.api.nvim_get_current_buf()
vim.cmd("stopinsert")
assert_true(term2_buf ~= term_buf, "Slot 2 should use a different terminal buffer")
assert_true(
	scroll_hook_count(term2_buf) == 0,
	"A terminal created with auto scroll off should have no hooks"
)

-- :CodockScroll on re-registers hooks for both the old and the new terminal.
vim.cmd("CodockScroll on")
assert_true(
	scroll_hook_count(term_buf) == 2,
	"CodockScroll on should restore the hook on the first terminal"
)
assert_true(
	scroll_hook_count(term2_buf) == 2,
	"CodockScroll on should register the hook on the second terminal"
)

-- ...and the behavior works again.
local term2_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_cursor(term2_win, { 1, 0 })
vim.api.nvim_set_current_win(other_win)
assert_true(
	vim.api.nvim_win_get_cursor(term2_win)[1] == vim.api.nvim_buf_line_count(term2_buf),
	"CodockScroll on should scroll the second terminal to the bottom on WinLeave"
)

-- A later setup() still resets the flag, but the old hooks stay gone because
-- the augroup is rebuilt with clear = true.
vim.cmd("CodockScroll toggle")
assert_true(
	require("codock.terminal").follow_output_enabled() == false,
	"Toggle should flip the flag off"
)
vim.cmd("CodockScroll toggle")
assert_true(
	require("codock.terminal").follow_output_enabled() == true,
	"Toggle should flip the flag back on"
)

print("codock scroll behavior can be toggled with CodockScroll")
vim.cmd("qa!")
