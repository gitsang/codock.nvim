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
	actions = {
		{
			name = "Legacy prompt",
			prompts = "legacy-action-prompt ",
		},
	},
})

local selected_action_name
local input_count = 0
vim.ui.select = function(items, _, callback)
	for _, item in ipairs(items) do
		if item.name == selected_action_name then
			callback(item)
			return
		end
	end
	fail("Action not found: " .. selected_action_name)
end
vim.ui.input = function(options, callback)
	assert_equal(options.prompt, "File position prefix: ", "Action requests a prefix")
	input_count = input_count + 1
	callback("@")
end

vim.cmd("edit tests/actions_execute_target.lua")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha" })
vim.cmd("1")

selected_action_name = "Yank file position"
vim.cmd("CodockActions")
assert_equal(vim.fn.getreg('"'), "@tests/actions_execute_target.lua:L1", "Yank action copies the prefixed position")
assert_true(require("codock.utils").find_codock_terminal() == nil, "Yank action should not open a codock terminal")

local source_win = vim.api.nvim_get_current_win()
vim.cmd("Codock")
local term_buf = vim.api.nvim_get_current_buf()
vim.cmd("stopinsert")
vim.api.nvim_set_current_win(source_win)

selected_action_name = "Paste file position"
vim.cmd("CodockActions")
local completed = vim.wait(1000, function()
	local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
	return table.concat(lines):find("@tests/actions_execute_target.lua:L1", 1, true) ~= nil
end, 20)

assert_true(completed, "Paste action should send the prefixed file position")

selected_action_name = "Legacy prompt"
vim.cmd("CodockActions")
local prompt_completed = vim.wait(1000, function()
	local lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
	return table.concat(lines):find("legacy-action-prompt", 1, true) ~= nil
end, 20)

assert_true(prompt_completed, "Prompt actions should continue sending text")
assert_equal(input_count, 2, "Both file position actions request a prefix")

print("codock execute actions support prompted file position prefixes")
vim.cmd("qa!")
