# codock.nvim

[English](./README.md) | 中文

一个 Neovim 插件，在垂直分割窗口中打开运行 Coding Agent CLI 工具（crush、opencode、claude、gemini-cli 等）的终端。

![Preview](./resources/Preview.gif)

## 1. 安装

使用 [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'gitsang/codock.nvim',
  opts = {
    width = 80, -- 垂直分割窗口的宽度
    codock_cmd = "opencode", -- 终端中运行的命令（crush、opencode、claude、gemini-cli 等）
    copy_to_clipboard = false, -- 复制到系统剪贴板
    actions = {},
  },
  cmd = { "Codock", "CodockFilePosPaste", "CodockFilePosYank", "CodockActions" },
  keys = {
    { "<leader>CC", "<cmd>Codock<cr>", desc = "Toggle Codock", mode = { "n", "v" } },
    { "<leader>CP", ":'<,'>CodockFilePosPaste @<cr>", desc = "Copy and paste file path and line info", mode = { "n", "v" } },
    { "<leader>CY", ":'<,'>CodockFilePosYank @<cr>", desc = "Copy file path and line info", mode = { "n", "v" } },
    { "<leader>CA", ":'<,'>CodockActions<cr>", desc = "Run Codock actions", mode = { "n", "v" } },
  },
}
```

## 2. 使用方法

安装完成后，你可以运行以下命令：

### 2.1 Codock 命令

运行 `:Codock` 命令在垂直分割窗口中打开运行配置的 AI CLI 命令的终端。终端会在 git 项目根目录中启动；如果没有 git 仓库，则在当前工作目录中启动。

你也可以指定不同的 CLI 工具作为参数：

- `:Codock` - 打开 `codock_cmd` 配置的默认 CLI 工具
- `:Codock claude` - 打开 claude
- `:Codock opencode` - 打开 opencode
- `:Codock gemini-cli` - 打开 gemini-cli

### 2.2 CodockFilePosPaste 和 CodockFilePosYank 命令

- `:CodockFilePosPaste [prefix]` 命令复制相对文件路径和行/列信息，然后发送给 AI CLI 工具。例如，`:CodockFilePosPaste @` 会复制并发送 `@path/to/file.lua:L1`。
- `:CodockFilePosYank [prefix]` 命令仅复制相对文件路径和行/列信息。例如，`:CodockFilePosYank @` 会复制 `@path/to/file.lua:L1`。
- 可选前缀默认为空字符串。
- `:CodockFilePos [prefix]` 保留为 `:CodockFilePosPaste [prefix]` 的向后兼容别名。

### 2.3 CodockActions 命令

`:CodockActions` 命令会打开包含默认及自定义 Actions 的弹出选择器。默认 Actions 包括复制和发送文件位置，选择后会通过 `vim.ui.input()` 请求可选前缀。

你可以在 [自定义 Actions 教程](docs/actions.zh-CN.md) 中了解如何定义 prompt 及 execute Action。

## 3. 支持的 AI CLI 工具

本插件支持多种 AI CLI 工具：

- `crush` - [Crush CLI](https://github.com/charmbracelet/crush)
- `opencode` - OpenCode
- `claude` - Claude Code
- `gemini-cli` - Gemini CLI

只需将 `codock_cmd` 选项设置为你首选的 AI CLI 工具即可。

## 4. 常见问题

### 4.1 临时关闭自动滚动到底部

当 codock 终端窗口失去焦点时，插件会自动将其滚动到底部，以便持续跟随最新输出（Neovim 仅在终端光标位于最后一行时才会跟随输出）。如果你想浏览终端输出而不希望它自动跳到底部，可以临时禁用该行为：

```vim
:autocmd! codock_nvim WinLeave
:autocmd! codock_nvim TermLeave
```

或使用 Lua：

```lua
vim.api.nvim_clear_autocmds({ group = "codock_nvim", event = { "WinLeave", "TermLeave" } })
```

> 滚动到底部的行为注册在 `WinLeave` 和 `TermLeave` 两个事件上，需要同时移除。另一条 `WinEnter` → `startinsert` 的 autocmd 不受影响。

重启 Neovim 即可重新启用（`setup()` 每次启动都会以 `clear = true` 重建 `codock_nvim` augroup）。
