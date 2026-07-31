local M = {}
local utils = require("codock.utils")

---Move a codock terminal window to the latest output.
---
---Neovim only tails terminal output while the terminal cursor is on the last
---line. Leaving terminal-mode early can leave the inactive window cursor at an
---older line, so put it back on the current last line before focus moves away.
---@param win integer terminal window
---@param buf integer terminal buffer
local function scroll_terminal_to_bottom(win, buf)
	if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(buf)
	pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
end

---Send text to codock terminal
---@param text string text to send
local function send_to_terminal(text)
	local buf = utils.find_codock_terminal()
	if not buf then
		return false
	end

	-- Find the window containing this buffer
	local wins = vim.api.nvim_list_wins()
	for _, win in ipairs(wins) do
		if vim.api.nvim_win_is_valid(win) then
			if vim.api.nvim_win_get_buf(win) == buf then
				-- Focus the terminal window
				vim.api.nvim_set_current_win(win)
				-- Send text to terminal
				vim.api.nvim_chan_send(vim.bo[buf].channel, text)
				return true
			end
		end
	end
	return false
end

---Open codock terminal in vertical split
---@param width integer terminal width
---@param codock_cmd string command to run
local function open_codock_terminal(width, codock_cmd, augroup)
	-- Create a vertical split
	vim.cmd("vsplit")
	local win = vim.api.nvim_get_current_win()

	-- Set window width
	-- Always set winfixwidth to prevent automatic width adjustments (like ctrl+w =)
	-- but allow manual width adjustments (like ctrl+w > / ctrl+w <)
	vim.api.nvim_win_set_width(win, width)
	vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
	vim.w[win].codock_terminal = true

	-- Open terminal and run codock command
	vim.cmd("terminal " .. codock_cmd)

	-- Set buffer options to hide from buffer tab
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
	vim.b[buf].codock_terminal = true

	-- Set up terminal key mappings for window navigation
	local term_opts = { buffer = buf, silent = true }
	vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", term_opts)
	vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", term_opts)
	vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", term_opts)
	vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", term_opts)

	-- Set up autocmd to enter terminal mode when entering codock terminal window
	vim.api.nvim_create_autocmd("WinEnter", {
		group = augroup,
		buffer = buf,
		callback = function()
			if vim.api.nvim_get_current_win() == win then
				vim.cmd("startinsert")
			end
		end,
	})

	-- Keep Neovim's native terminal tailing active after the window loses focus.
	vim.api.nvim_create_autocmd({ "TermLeave", "WinLeave" }, {
		group = augroup,
		buffer = buf,
		callback = function()
			scroll_terminal_to_bottom(win, buf)
		end,
	})

	-- Enter terminal mode immediately
	vim.cmd("startinsert")
end

---Send text to an existing codock terminal or open one first.
---@param text string text to send
---@param width integer terminal width
---@param codock_cmd string command to run
local function send_to_codock(text, width, codock_cmd, augroup)
	if utils.find_codock_terminal() then
		send_to_terminal(text)
		return
	end

	open_codock_terminal(width, codock_cmd, augroup)
	vim.defer_fn(function()
		send_to_terminal(text)
	end, 3000)
end

---@class CodockActionContext
---@field send fun(text: string)

---@class CodockAction
---@field name string
---@field description? string
---@field prompts? string|fun():string
---@field execute? fun(context: CodockActionContext)

---@class CodockOptions
---@field width? integer
---@field codock_cmd? string
---@field copy_to_clipboard? boolean
---@field actions? CodockAction[]

---Handle CodockActions command
---@param opts CodockOptions configuration options
---@param width integer terminal width
---@param codock_cmd string command to run
local function handle_codock_actions(opts, width, codock_cmd, augroup)
	if not opts.actions or #opts.actions == 0 then
		vim.notify("No actions configured", vim.log.levels.WARN)
		return
	end

	-- Prepare items for selection
	local items = {}
	for _, action in ipairs(opts.actions) do
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
				send = function(text)
					send_to_codock(text, width, codock_cmd, augroup)
				end,
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

		send_to_codock(prompt, width, codock_cmd, augroup)
	end)
end

---Setup function for codock.nvim
---@param opts? CodockOptions
function M.setup(opts)
	opts = opts or {}
	local width = opts.width or 80
	local codock_cmd = opts.codock_cmd or "codock"
	local copy_to_clipboard = opts.copy_to_clipboard ~= false -- default to true
	local augroup = vim.api.nvim_create_augroup("codock_nvim", { clear = true })
	local default_actions = require("codock.actions.default").create({
		copy_to_clipboard = copy_to_clipboard,
		send = function(text)
			send_to_codock(text, width, codock_cmd, augroup)
		end,
	})

	-- Initialize actions array if not provided
	if not opts.actions then
		opts.actions = {}
	end

	-- Load default actions and insert them at the beginning
	for i = #default_actions.actions, 1, -1 do
		table.insert(opts.actions, 1, default_actions.actions[i])
	end

	-- Create Codock command (supports optional argument: :Codock [cmd])
	vim.api.nvim_create_user_command("Codock", function(cmd_opts)
		local cmd = cmd_opts.args
		if cmd == "" then
			cmd = codock_cmd
		end
		open_codock_terminal(width, cmd, augroup)
	end, { nargs = "?" })
	vim.api.nvim_create_user_command("CodockActions", function()
		handle_codock_actions(opts, width, codock_cmd, augroup)
	end, { range = true })
	default_actions.register_commands()
end

return M
