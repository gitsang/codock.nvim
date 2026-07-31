# 自定义 Actions 教程

[English](./actions.md)

本教程教你如何为 `codock.nvim` 配置自定义 actions。

## 1. CodockAction 基本结构

每个 action 包含以下字段：

```lua
{
    name = "Action 名称",
    description = "可选的描述信息",
    prompts = "字符串或函数", -- prompts 和 execute 二选一
    execute = function(context) end
}
```

### 1.1 字段说明

- `name` (必需): action 的显示名称
- `description` (可选): 附加说明信息
- `prompts` (可选): 可以是字符串或函数
  - 字符串: 直接发送到 codock 终端的文本
  - 函数: 返回要发送的字符串，支持动态生成内容
- `execute` (可选): 执行自定义操作，不会自动发送 prompt
  - `context.send(text)`: 将文本发送到 codock 终端，必要时自动打开终端
- 每个 Action 必须提供 `prompts` 或 `execute`。两者同时存在时优先执行 `execute`。

## 2. 示例 1: 简单字符串 Prompts

最简单的 action 使用静态字符串：

```lua
require("codock").setup({
    actions = {
        {
            name = "Explain this code",
            description = "Ask AI to explain the selected code",
            prompts = "Please explain this code in detail."
        },
        {
            name = "Refactor this code",
            prompts = "Please refactor this code to improve readability and performance."
        }
    }
})
```

## 3. 示例 2: 函数式 Prompts（参考 analyze_and_fix_diagnostics）

当需要动态生成内容时，使用函数作为 `prompts`。这是 `lua/codock/actions/analyze_and_fix_diagnostics.lua` 的示例：

```lua
{
    name = "Analyze and fix diagnostics",
    description = "Show and analyze diagnostics in the selected range",
    prompts = function()
        local current_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
        local start_line = vim.fn.line("'<")
        local end_line = vim.fn.line("'>")

        -- 如果不在 visual mode，使用当前行
        if vim.fn.visualmode() == "" then
            start_line = vim.fn.line(".")
            end_line = start_line
        end

        -- 获取诊断信息
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

## 4. 示例 3: 使用用户输入的 Execute Action

需要副作用或异步输入时可以使用 `execute`：

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

`vim.ui.input()` 返回 `nil` 表示用户取消操作。

## 5. 使用 Actions

配置好 actions 后：

1. 使用 `:CodockActions` 命令打开选择器
2. 选择需要的 action
3. action 的 prompts 会自动发送到 codock 终端

## 6. 默认 Actions

插件提供了默认 Actions（参见 `lua/codock/actions/default.lua`），包括复制和发送文件位置的 Action。这两个文件位置 Action 都会通过 `vim.ui.input()` 请求可选前缀。自定义 Actions 会与默认 Actions 一起显示。

## 7. 注意事项

1. `prompts` 函数应该返回一个字符串
2. `prompts` 或 `execute` 函数会在 Action 被选中时立即调用
3. 如果访问 visual mode 相关信息（如 `'<`, `'>`），确保从 visual mode 调用命令
4. 保持 prompts 简洁有效，避免生成过长的文本
5. 可以使用 `vim.notify()` 在函数中显示调试信息