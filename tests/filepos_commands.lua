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

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		fail(string.format("%s: expected %q, got %q", message, expected, actual))
	end
end

require("codock").setup({
	width = 40,
	codock_cmd = "cat",
	copy_to_clipboard = false,
})

vim.cmd("edit tests/filepos_target.lua")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta" })
vim.cmd("1")

vim.cmd("CodockFilePosYank")
assert_equal(vim.fn.getreg('"'), "tests/filepos_target.lua:L1", "Yank command updates unnamed register")
assert_equal(vim.fn.getreg("0"), "tests/filepos_target.lua:L1", "Yank command updates yank register")
assert_true(
	require("codock.utils").find_codock_terminal() == nil,
	"Yank command should not open a codock terminal"
)

local source_win = vim.api.nvim_get_current_win()
vim.cmd("Codock")
local term_buf = vim.api.nvim_get_current_buf()
vim.cmd("stopinsert")
vim.api.nvim_set_current_win(source_win)

vim.cmd("CodockFilePosPaste")
local completed = vim.wait(1000, function()
	local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
	for _, line in ipairs(lines) do
		if line:find("tests/filepos_target.lua:L1", 1, false) then
			return true
		end
	end
	return false
end, 20)

assert_true(completed, "Paste command should send file position to codock terminal")
print("codock file position yank and paste commands work")
vim.cmd("qa!")
