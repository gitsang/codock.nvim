local M = {}
local utils = require("codock.utils")
local terminal = require("codock.terminal")
local commands = require("codock.commands")

---@class CodockOptions
---@field width? integer
---@field codock_cmd? string
---@field copy_to_clipboard? boolean
---@field actions? CodockAction[]

---Setup function for codock.nvim
---@param opts? CodockOptions
function M.setup(opts)
	opts = opts or {}

	local state = {
		width = opts.width or 80,
		codock_cmd = opts.codock_cmd or "codock",
	}
	local copy_to_clipboard = opts.copy_to_clipboard ~= false -- default to true
	local augroup = vim.api.nvim_create_augroup("codock_nvim", { clear = true })

	-- Track the most recently focused codock terminal so commands such as
	-- CodockFilePosPaste and CodockActions send to the terminal the user
	-- last used instead of the first terminal buffer.
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
		group = augroup,
		callback = function()
			utils.track_current_codock_terminal()
		end,
	})

	local function send(text)
		terminal.send_or_open(text, state.width, state.codock_cmd, augroup)
	end

	local default_actions = require("codock.actions.default").create({
		copy_to_clipboard = copy_to_clipboard,
		send = send,
	})

	-- Initialize actions array if not provided
	if not opts.actions then
		opts.actions = {}
	end

	-- Load default actions and insert them at the beginning
	for i = #default_actions.actions, 1, -1 do
		table.insert(opts.actions, 1, default_actions.actions[i])
	end

	commands.register({
		state = state,
		augroup = augroup,
		actions = opts.actions,
		send = send,
	})

	default_actions.register_commands()
end

return M
