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

require("codock").setup({
	width = 42,
	codock_cmd = "cat",
	copy_to_clipboard = false,
})

vim.cmd("enew")

-- Open the first codock terminal.
vim.cmd("Codock")
local term1_win = vim.api.nvim_get_current_win()
local term1_buf = vim.api.nvim_get_current_buf()
vim.cmd("stopinsert")

local source_win
for _, win in ipairs(vim.api.nvim_list_wins()) do
	if win ~= term1_win then
		source_win = win
		break
	end
end
assert_true(source_win ~= nil, "Expected a source window next to the first terminal")

-- Open the second codock terminal from the source window.
vim.api.nvim_set_current_win(source_win)
vim.cmd("2Codock")
local term2_win = vim.api.nvim_get_current_win()
vim.cmd("stopinsert")

-- Resize all codock terminal windows at once.
vim.cmd("CodockWidth 30")
assert_true(
	vim.api.nvim_win_get_width(term1_win) == 30,
	string.format(
		"Expected first codock terminal width 30 after CodockWidth, got %d",
		vim.api.nvim_win_get_width(term1_win)
	)
)
assert_true(
	vim.api.nvim_win_get_width(term2_win) == 30,
	string.format(
		"Expected second codock terminal width 30 after CodockWidth, got %d",
		vim.api.nvim_win_get_width(term2_win)
	)
)

-- New terminals should use the width set by CodockWidth.
vim.api.nvim_win_close(term2_win, true)
vim.api.nvim_set_current_win(source_win)
vim.cmd("3Codock")
local term3_win = vim.api.nvim_get_current_win()
assert_true(
	vim.api.nvim_win_get_width(term3_win) == 30,
	string.format(
		"Expected new codock terminal width 30 after CodockWidth, got %d",
		vim.api.nvim_win_get_width(term3_win)
	)
)

-- CodockWidth can also enlarge windows when there is enough room.
vim.api.nvim_win_close(term3_win, true)
vim.cmd("CodockWidth 42")
assert_true(
	vim.api.nvim_win_get_width(term1_win) == 42,
	string.format(
		"Expected first codock terminal width 42 after CodockWidth 42, got %d",
		vim.api.nvim_win_get_width(term1_win)
	)
)

-- The terminal buffer is still marked as a codock terminal.
assert_true(require("codock.utils").is_codock_terminal(term1_buf), "Expected terminal buffer to remain a codock terminal")

print("codock width command resizes all codock terminal windows and updates the default width")
vim.cmd("qa!")
