local M = {}
local terminal = require("codock.terminal")
local action_select = require("codock.actions.select")

---@class CodockCommandState
---@field width integer
---@field codock_cmd string

---@class CodockCommandOptions
---@field state CodockCommandState
---@field augroup integer
---@field actions CodockAction[]
---@field send fun(text: string)

---Register the Codock user commands.
---@param opts CodockCommandOptions
function M.register(opts)
	local state = opts.state
	local augroup = opts.augroup
	local actions = opts.actions
	local send = opts.send

	-- Create Codock command. It toggles the terminal slot given by the count:
	--   :Codock       toggle slot 1
	--   :2Codock      toggle slot 2
	--   :3Codock pi   toggle slot 3 (using "pi" when slot 3 is created)
	vim.api.nvim_create_user_command("Codock", function(cmd_opts)
		local cmd = cmd_opts.args
		if cmd == "" then
			cmd = state.codock_cmd
		end

		-- A count typed before a mapping (e.g. 2<leader>CCP) is exposed in
		-- vim.v.count, while :2Codock is exposed in cmd_opts.count.
		local count = vim.v.count > 0 and vim.v.count or cmd_opts.count
		terminal.toggle(count, state.width, cmd, augroup)
	end, { nargs = "?", count = 1 })

	vim.api.nvim_create_user_command("CodockActions", function()
		action_select.run(actions, send)
	end, { range = true })

	-- Create CodockWidth command to resize all codock terminal windows at once.
	-- The new width is also used for terminals opened afterwards.
	vim.api.nvim_create_user_command("CodockWidth", function(cmd_opts)
		local new_width = state.width
		if cmd_opts.args ~= "" then
			local parsed = tonumber(cmd_opts.args)
			if not parsed or parsed < 1 then
				vim.notify("CodockWidth requires a positive integer width", vim.log.levels.ERROR)
				return
			end
			new_width = math.floor(parsed)
		end

		state.width = new_width
		local resized_count = terminal.resize_all(state.width)
		if resized_count == 0 then
			vim.notify(
				string.format("No codock terminal windows found; new windows will use width %d", state.width),
				vim.log.levels.INFO
			)
		end
	end, { nargs = "?" })
end

return M
