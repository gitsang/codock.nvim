local M = {}

---@class CodockActionContext
---@field send fun(text: string)

---@class CodockAction
---@field name string
---@field description? string
---@field prompts? string|fun():string
---@field execute? fun(context: CodockActionContext)

---Show a popup selector for codock actions and run the selected action.
---@param actions CodockAction[] configured actions
---@param send fun(text: string) send text to the most recently used terminal
function M.run(actions, send)
	if not actions or #actions == 0 then
		vim.notify("No actions configured", vim.log.levels.WARN)
		return
	end

	-- Prepare items for selection
	local items = {}
	for _, action in ipairs(actions) do
		table.insert(items, {
			name = action.name,
			description = action.description or "",
			action = action,
		})
	end

	-- Show popup selector
	vim.ui.select(items, {
		prompt = "Select action:",
		format_item = function(item)
			if item.description ~= "" then
				return item.name .. " - " .. item.description
			else
				return item.name
			end
		end,
	}, function(selected)
		if not selected then
			return
		end

		local action = selected.action
		if action.execute then
			action.execute({
				send = send,
			})
			return
		end

		local prompt
		if type(action.prompts) == "function" then
			prompt = action.prompts()
		else
			prompt = action.prompts
		end

		if type(prompt) ~= "string" then
			vim.notify("Action must define prompts or execute", vim.log.levels.ERROR)
			return
		end

		send(prompt)
	end)
end

return M
