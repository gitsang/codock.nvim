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

local width = 42
require("codock").setup({
	width = width,
	codock_cmd = "cat",
	copy_to_clipboard = false,
})

vim.cmd("enew")
vim.cmd("Codock")
local term_win = vim.api.nvim_get_current_win()

assert_true(
	vim.api.nvim_win_get_width(term_win) == width,
	string.format(
		"Expected codock terminal width %d, got %d",
		width,
		vim.api.nvim_win_get_width(term_win)
	)
)
assert_true(
	vim.api.nvim_get_option_value("winfixwidth", { win = term_win }),
	"Expected codock terminal window to set winfixwidth"
)

print("codock terminal width remains fixed on open")
vim.cmd("qa!")
