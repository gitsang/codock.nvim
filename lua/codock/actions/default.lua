local M = {}

---@class CodockDefaultActionsOptions
---@field copy_to_clipboard boolean
---@field send fun(text: string)

---@class CodockDefaultActions
---@field actions CodockAction[]
---@field register_commands fun()

---Create the built-in actions and their optional command integrations.
---@param options CodockDefaultActionsOptions
---@return CodockDefaultActions
function M.create(options)
	local features = {
		require("codock.actions.file_position").create(options),
	}
	local actions = {
		require("codock.actions.analyze_and_fix_diagnostics").get_action(),
	}

	for _, feature in ipairs(features) do
		for _, action in ipairs(feature.actions) do
			table.insert(actions, action)
		end
	end

	return {
		actions = actions,
		register_commands = function()
			for _, feature in ipairs(features) do
				feature.register_commands()
			end
		end,
	}
end

return M
