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

local function assert_eq(expected, actual, message)
	if expected ~= actual then
		fail(string.format("%s (expected %q, got %q)", message, expected, actual))
	end
end

require("codock").setup({
	width = 40,
	codock_cmd = "cat",
	copy_to_clipboard = false,
})

-- Open Codock from a subdirectory of the git repo. The terminal should still
-- start at the git project root instead of the subdirectory.
local subdir = root .. "/.tmp_codock_terminal_cwd_test"
vim.fn.mkdir(subdir, "p")
vim.cmd("cd " .. vim.fn.fnameescape(subdir))

vim.cmd("enew")
vim.cmd("Codock")
local term_buf = vim.api.nvim_get_current_buf()

local term_cwd = require("codock.utils").get_terminal_cwd()

vim.cmd("cd " .. vim.fn.fnameescape(root))
vim.fn.delete(subdir, "rf")

assert_true(term_buf ~= nil and vim.bo[term_buf].buftype == "terminal", "Codock did not open a terminal buffer")
assert_eq(root, term_cwd, "Codock terminal should start in the git project root")
print("codock terminal starts in the git project root")
vim.cmd("qa!")
