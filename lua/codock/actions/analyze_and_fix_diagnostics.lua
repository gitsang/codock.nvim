local M = {}
local utils = require("codock.utils")

---Format a diagnostic as a string
---@param diagnostic table diagnostic info
---@return string
local function format_diagnostic(diagnostic)
	local source = diagnostic.source or "unknown"
	local code = diagnostic.code or ""
	local message = diagnostic.message

	if code ~= "" then
		return string.format("[%s:%s] %s", source, code, message)
	else
		return string.format("[%s] %s", source, message)
	end
end

---Get diagnostics in visual range and format them
---@return string prompt
local function get_diagnostics_prompt()
	local current_file = utils.get_current_file()
	local start_line, end_line = utils.get_visual_range()
	local buf = vim.api.nvim_get_current_buf()

	-- Get all diagnostics for the buffer
	local diagnostics = vim.diagnostic.get(buf)

	-- Filter diagnostics within the visual range
	local filtered = {}
	for _, diag in ipairs(diagnostics) do
		if diag.lnum >= start_line - 1 and diag.lnum <= end_line - 1 then
			table.insert(filtered, diag)
		end
	end

	-- Sort by line number
	table.sort(filtered, function(a, b)
		return a.lnum < b.lnum
	end)

	-- Format the prompt
	local result = "Help me analyze and fix diagnostics from "

	-- Add file and range info
	if start_line == end_line then
		result = result .. string.format("%s:L%d\n\n", current_file, start_line)
	else
		result = result .. string.format("%s:L%d-L%d\n\n", current_file, start_line, end_line)
	end

	-- Add diagnostics
	if #filtered == 0 then
		result = result .. "No diagnostics found in the selected range."
	else
		for _, diag in ipairs(filtered) do
			local line_num = diag.lnum + 1 -- Convert 0-based to 1-based
			local formatted = format_diagnostic(diag)
			result = result .. string.format("L%d: %s\n\n", line_num, formatted)
		end
	end

	return result
end

---Get analyze and fix diagnostics action
---@return CodockAction
function M.get_action()
	return {
		name = "Analyze and fix diagnostics",
		description = "Analyze and fix diagnostics in the selected range",
		prompts = get_diagnostics_prompt,
	}
end

return M
