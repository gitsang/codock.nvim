# Custom Actions Tutorial

[中文](./actions.zh-CN.md)

This tutorial teaches you how to configure custom actions for `codock.nvim`.

## 1. CodockAction Basic Structure

Each action contain the following fields:

```lua
{
    name = "Action name",
    description = "Optional description",
    prompts = "String or function", -- Use prompts or execute
    execute = function(context) end
}
```

### 1.1 Field Descriptions

- `name` (required): Display name of the action
- `description` (optional): Additional description information
- `prompts` (optional): Can be a string or function
  - String: Text directly sent to codock terminal
  - Function: Returns the string to send, supports dynamic content generation
- `execute` (optional): Runs custom behavior instead of automatically sending a prompt
  - `context.send(text)`: Sends text to the codock terminal, opening it when needed
- Each action must define either `prompts` or `execute`. If both are present, `execute` takes precedence.

## 2. Example 1: Simple String Prompts

The simplest action uses a static string:

```lua
require("codock").setup({
    actions = {
        {
            name = "Explain this code",
            description = "Ask AI to explain selected code",
            prompts = "Please explain this code in detail."
        },
        {
            name = "Refactor this code",
            prompts = "Please refactor this code to improve readability and performance."
        }
    }
})
```

## 3. Example 2: Function Prompts (Reference analyze_and_fix_diagnostics)

When you need to dynamically generate content, use a function as `prompts`. Here's an example from `lua/codock/actions/analyze_and_fix_diagnostics.lua`:

```lua
{
    name = "Analyze and fix diagnostics",
    description = "Show and analyze diagnostics in the selected range",
    prompts = function()
        local current_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
        local start_line = vim.fn.line("'<")
        local end_line = vim.fn.line("'>")

        -- If not in visual mode, use current line
        if vim.fn.visualmode() == "" then
            start_line = vim.fn.line(".")
            end_line = start_line
        end

        -- Get diagnostic information
        local diagnostics = vim.diagnostic.get(0)
        local result = string.format("%s:L%d-L%d\n\n", current_file, start_line, end_line)

        for _, diag in ipairs(diagnostics) do
            if diag.lnum >= start_line - 1 and diag.lnum <= end_line - 1 then
                result = result .. string.format("L%d: [%s] %s\n",
                    diag.lnum + 1,
                    diag.source or "unknown",
                    diag.message
                )
            end
        end

        return result
    end,
}
```

## 4. Example 3: Execute Action with User Input

Use `execute` when an action needs side effects or asynchronous input:

```lua
{
    name = "Send with prefix",
    execute = function(context)
        vim.ui.input({ prompt = "Prefix: ", default = "" }, function(prefix)
            if prefix ~= nil then
                context.send(prefix .. "Please review this code.")
            end
        end)
    end,
}
```

Returning `nil` from `vim.ui.input()` means the user cancelled the action.

## 5. Using Actions

After configuring actions:

1. Use `:CodockActions` command to open the selector
2. Select the desired action
3. The action's prompts will be automatically sent to the codock terminal

## 6. Default Actions

The plugin provides default actions (see `lua/codock/actions/default.lua`), including actions for yanking and pasting file positions. Both file position actions request an optional prefix through `vim.ui.input()`. Custom actions are displayed together with the defaults.

## 7. Notes

1. A `prompts` function should return a string
2. The `prompts` or `execute` function is called immediately when the action is selected
3. If accessing visual mode related information (like `'<`, `'>`), ensure the command is called from visual mode
4. Keep prompts concise and effective, avoid generating overly long text
5. You can use `vim.notify()` in the function to display debug information