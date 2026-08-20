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

local function buffer_contains(buf, needle)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	return table.concat(lines):find(needle, 1, true) ~= nil
end

local function wait_for_buffer_contains(buf, needle)
	return vim.wait(1000, function()
		return buffer_contains(buf, needle)
	end, 20)
end

require("codock").setup({
	width = 40,
	codock_cmd = "cat",
	copy_to_clipboard = false,
})

vim.cmd("edit tests/toggle_terminal_target.lua")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha" })
vim.cmd("1")

-- :Codock opens slot 1.
vim.cmd("Codock")
local slot1_buf = vim.api.nvim_get_current_buf()
local slot1_win = vim.api.nvim_get_current_win()
vim.cmd("stopinsert")
assert_true(require("codock.utils").is_codock_terminal(slot1_buf), "Slot 1 should open a codock terminal")

local source_win
for _, win in ipairs(vim.api.nvim_list_wins()) do
	if win ~= slot1_win then
		source_win = win
		break
	end
end
assert_true(source_win ~= nil, "Expected a source window next to slot 1")

-- :Codock again hides slot 1 but keeps its buffer and terminal process alive.
vim.api.nvim_set_current_win(source_win)
vim.cmd("Codock")
assert_true(not vim.api.nvim_win_is_valid(slot1_win), "Slot 1 window should be hidden")
assert_true(vim.api.nvim_buf_is_valid(slot1_buf), "Slot 1 buffer should stay alive")
assert_true(#vim.fn.win_findbuf(slot1_buf) == 0, "Slot 1 buffer should have no visible window")

-- :Codock a third time shows the same slot 1 buffer again.
vim.cmd("Codock")
assert_true(vim.api.nvim_get_current_buf() == slot1_buf, "Slot 1 should be shown again with the same buffer")
vim.cmd("stopinsert")

-- :2:Codock opens slot 2 without touching slot 1.
vim.api.nvim_set_current_win(source_win)
vim.cmd("2:Codock")
local slot2_buf = vim.api.nvim_get_current_buf()
local slot2_win = vim.api.nvim_get_current_win()
vim.cmd("stopinsert")
assert_true(slot2_buf ~= slot1_buf, "Slot 2 should use a different terminal buffer")

-- :2:Codock again hides slot 2.
vim.api.nvim_set_current_win(source_win)
vim.cmd("2:Codock")
assert_true(not vim.api.nvim_win_is_valid(slot2_win), "Slot 2 window should be hidden")
assert_true(vim.api.nvim_buf_is_valid(slot2_buf), "Slot 2 buffer should stay alive")

-- Pasting to the most recently focused terminal should reopen it when hidden.
vim.api.nvim_set_current_win(source_win)
vim.cmd("CodockFilePosPaste hidden")
assert_true(#vim.fn.win_findbuf(slot2_buf) > 0, "Paste should reopen the hidden slot 2 terminal")
assert_true(wait_for_buffer_contains(slot2_buf, "hidden"), "Hidden slot 2 should receive the paste text")

-- A count before a <cmd> mapping should toggle the requested slot as well.
vim.api.nvim_set_current_win(source_win)
vim.cmd("stopinsert")
vim.keymap.set("n", "<F2>", "<cmd>Codock cat<cr>", { silent = true })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("3<F2>", true, false, true), "xt", false)
local slot3_opened = vim.wait(1000, function()
	return require("codock.terminal").get_slot(3) ~= nil
end, 20)
assert_true(slot3_opened, "3 before a Codock mapping should toggle slot 3")

print("codock toggles terminal windows by count")
vim.cmd("qa!")
