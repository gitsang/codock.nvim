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

local output_lines = 50
local cmd = string.format(
	"sh -c 'for i in $(seq 1 %d); do echo codock-scroll-$i; sleep 0.01; done; sleep 0.1'",
	output_lines
)

require("codock").setup({
	width = 40,
	codock_cmd = cmd,
	copy_to_clipboard = false,
})

vim.cmd("enew")
vim.cmd("Codock")

local term_win = vim.api.nvim_get_current_win()
local term_buf = vim.api.nvim_get_current_buf()
assert_true(vim.bo[term_buf].buftype == "terminal", "Codock did not open a terminal buffer")

-- Reproduce the user path: leave the streaming terminal visible but unfocused.
vim.cmd("stopinsert")
local wins = vim.api.nvim_list_wins()
for _, win in ipairs(wins) do
	if win ~= term_win then
		vim.api.nvim_set_current_win(win)
		break
	end
end
assert_true(
	vim.api.nvim_get_current_win() ~= term_win,
	"Failed to move focus away from codock terminal"
)

local completed = vim.wait(3000, function()
	if not vim.api.nvim_buf_is_valid(term_buf) then
		return false
	end
	local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
	for _, line in ipairs(lines) do
		if line:find("codock%-scroll%-" .. output_lines, 1, false) then
			return true
		end
	end
	return false
end, 20)
assert_true(completed, "Terminal command did not produce the expected final output")

-- Give any scheduled viewport updates a chance to run.
vim.wait(200, function()
	return false
end, 20)

local line_count = vim.api.nvim_buf_line_count(term_buf)
local cursor = vim.api.nvim_win_get_cursor(term_win)
local view = vim.api.nvim_win_call(term_win, function()
	return vim.fn.winsaveview()
end)

assert_true(
	cursor[1] == line_count,
	string.format(
		"Expected inactive codock terminal cursor to follow output "
			.. "(cursor=%d, line_count=%d, topline=%d)",
		cursor[1],
		line_count,
		view.topline
	)
)

print(string.format(
	"inactive codock terminal followed output: cursor=%d line_count=%d topline=%d",
	cursor[1],
	line_count,
	view.topline
))
vim.cmd("qa!")
