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

vim.cmd("edit tests/multiple_terminals_target.lua")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha" })
vim.cmd("1")

-- Open the first codock terminal.
vim.cmd("Codock")
local term1_buf = vim.api.nvim_get_current_buf()
local term1_win = vim.api.nvim_get_current_win()
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
local term2_buf = vim.api.nvim_get_current_buf()
local term2_win = vim.api.nvim_get_current_win()
vim.cmd("stopinsert")
vim.api.nvim_set_current_win(source_win)

-- Focus the first terminal, then send from the source window. The paste
-- command should go to the first terminal because it was focused last.
vim.api.nvim_set_current_win(term1_win)
vim.cmd("stopinsert")
vim.api.nvim_set_current_win(source_win)
assert_true(
	require("codock.utils").find_codock_terminal() == term1_buf,
	"Expected the first terminal to be the last focused codock terminal"
)

vim.cmd("CodockFilePosPaste first")
assert_true(
	wait_for_buffer_contains(term1_buf, "first"),
	"First terminal should receive text when it was focused last"
)
assert_true(
	not buffer_contains(term2_buf, "first"),
	"Second terminal should not receive text sent to the first terminal"
)

-- Now focus the second terminal and verify the paste command follows it.
vim.api.nvim_set_current_win(term2_win)
vim.cmd("stopinsert")
vim.api.nvim_set_current_win(source_win)
assert_true(
	require("codock.utils").find_codock_terminal() == term2_buf,
	"Expected the second terminal to be the last focused codock terminal"
)

vim.cmd("CodockFilePosPaste second")
assert_true(
	wait_for_buffer_contains(term2_buf, "second"),
	"Second terminal should receive text when it was focused last"
)
assert_true(
	not buffer_contains(term1_buf, "second"),
	"First terminal should not receive text sent to the second terminal"
)

print("codock sends input to the most recently focused terminal")
vim.cmd("qa!")
