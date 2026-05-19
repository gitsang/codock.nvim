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
	width = 40,
	codock_cmd = "cat",
	copy_to_clipboard = false,
})

vim.cmd("enew")
vim.cmd("Codock")
local term_buf = vim.api.nvim_get_current_buf()

vim.api.nvim_chan_send(vim.bo[term_buf].channel, "codock-input-roundtrip\n")
local completed = vim.wait(1000, function()
	local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
	for _, line in ipairs(lines) do
		if line:find("codock%-input%-roundtrip", 1, false) then
			return true
		end
	end
	return false
end, 20)

assert_true(completed, "Codock terminal did not accept channel input")
print("codock terminal accepted channel input")
vim.cmd("qa!")
