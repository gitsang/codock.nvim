local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

local function fail(message)
	error(message, 0)
end

require("codock").setup({
	width = 40,
	codock_cmd = "cat",
	copy_to_clipboard = false,
})

vim.cmd("edit tests/filepos_default_target.lua")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha" })
vim.cmd("1")

local source_win = vim.api.nvim_get_current_win()
vim.cmd("Codock")
local term_buf = vim.api.nvim_get_current_buf()
vim.cmd("stopinsert")
vim.api.nvim_set_current_win(source_win)

vim.cmd("CodockFilePosPaste")
local expected = "tests/filepos_default_target.lua:L1"
local completed = vim.wait(1000, function()
	local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
	for _, line in ipairs(lines) do
		if line:find(expected, 1, true) and not line:find("@" .. expected, 1, true) then
			return true
		end
	end
	return false
end, 20)

if not completed then
	fail("CodockFilePosPaste should use an empty prefix by default")
end

print("codock file position paste prefix defaults to empty")
vim.cmd("qa!")
