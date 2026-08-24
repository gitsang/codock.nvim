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
    codock_cmd = "pi", -- 终端中运行的命令（pi、opencode、claude、codex 等）
    copy_to_clipboard = false, -- 复制到系统剪贴板
    header = true, -- 在每个终端窗口上方显示一行带槽位号的头部
    actions = {},
  },
  cmd = { "Codock", "CodockFilePosPaste", "CodockFilePosYank", "CodockActions", "CodockWidth" },
  keys = {
      { "<leader>CCO", "<cmd>Codock opencode<cr>", desc = "Toggle Opencode", mode = { "n", "v" } },
      { "<leader>CCC", "<cmd>Codock claude<cr>", desc = "Toggle Claude", mode = { "n", "v" } },
      { "<leader>CCX", "<cmd>Codock codex<cr>", desc = "Toggle Codex", mode = { "n", "v" } },
      { "<leader>CCP", "<cmd>Codock pi<cr>", desc = "Toggle Pi Agent", mode = { "n", "v" } },
      { "<leader>CCD", "<cmd>Codock dsh --profile tui<cr>", desc = "Toggle Deepseek Harness TUI", mode = { "n", "v" } },
      { "<leader>CY", ":'<,'>CodockFilePosYank<cr>", desc = "Copy file position", mode = { "n", "v" } },
      { "<leader>CP", ":'<,'>CodockFilePosPaste<cr>", desc = "Copy and paste file position", mode = { "n", "v" } },
      { "<leader>CA", ":'<,'>CodockActions<cr>", desc = "Run Codock actions", mode = { "n", "v" } },
  },
}
```

## 2. 使用方法

安装完成后，你可以运行以下命令：

### 2.1 Codock 命令

`:Codock` 命令会在垂直分割窗口中开启或隐藏 codock 终端。每个终端绑定一个数字槽位：

- `:Codock` - Toggle 槽位 1
- `:2:Codock` 或 `:2Codock` - Toggle 槽位 2
- `:3:Codock claude` - Toggle 槽位 3（槽位 3 不存在时使用 `claude` 创建）

如果槽位还没有终端，`:Codock` 会创建运行配置的 AI CLI 命令的终端。终端会在 git 项目根目录中启动；如果没有 git 仓库，则在当前工作目录中启动。如果槽位已有可见终端，`:Codock` 会隐藏它的窗口。如果槽位已有隐藏终端，`:Codock` 会在新分割窗口中重新显示它，并复用同一个 buffer 和进程。

count 在 mapping 前同样生效，因此 `2<leader>CCP` 会 toggle 上面配置中 `<leader>CCP` 对应的槽位 2。

你也可以在创建槽位时指定不同的 CLI 工具作为参数：

- `:Codock` - Toggle 槽位 1，使用 `codock_cmd` 配置的默认 CLI 工具
- `:Codock claude` - Toggle 槽位 1（槽位 1 不存在时使用 claude 创建）
- `:2Codock opencode` - Toggle 槽位 2（槽位 2 不存在时使用 opencode 创建）
- `:2Codock gemini-cli` - Toggle 槽位 2（槽位 2 不存在时使用 gemini-cli 创建）

> 如果需要在已有终端旁边运行另一个 CLI 工具，请使用其他槽位，例如 `:2Codock claude`。

每个可见终端会显示一行带有槽位号的头部，基于 `winbar` 选项绘制（需要 Neovim 0.11+；旧版本不显示头部）。头部使用 `CodockHeader` 高亮组（默认链接到 `StatusLine`），可通过 `header = false` 关闭。

### 2.2 CodockFilePosPaste 和 CodockFilePosYank 命令

- `:CodockFilePosPaste [prefix]` 命令复制相对文件路径和行/列信息，然后发送给 AI CLI 工具。例如，`:CodockFilePosPaste @` 会复制并发送 `@path/to/file.lua:L1`。
- `:CodockFilePosYank [prefix]` 命令仅复制相对文件路径和行/列信息。例如，`:CodockFilePosYank @` 会复制 `@path/to/file.lua:L1`。
- 可选前缀默认为空字符串。
- `:CodockFilePos [prefix]` 保留为 `:CodockFilePosPaste [prefix]` 的向后兼容别名。

### 2.3 CodockActions 命令

`:CodockActions` 命令会打开包含默认及自定义 Actions 的弹出选择器。默认 Actions 包括复制和发送文件位置，选择后会通过 `vim.ui.input()` 请求可选前缀。

需要向终端发送文本时（例如 `CodockFilePosPaste` 和 Actions），会优先发送到最近聚焦的 codock 终端；如果该终端窗口已隐藏，会先重新显示它。如果不存在 codock 终端，则自动打开一个。

你可以在 [自定义 Actions 教程](docs/actions.zh-CN.md) 中了解如何定义 prompt 及 execute Action。

### 2.4 CodockWidth 命令

`:CodockWidth [width]` 将所有已打开的 codock 终端窗口宽度统一调整为 `width`，之后新打开的终端也会使用该宽度。

- `:CodockWidth 30` - 将所有 codock 终端窗口宽度调整为 30 列
- `:CodockWidth` - 将所有 codock 终端窗口重置为当前使用的宽度

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
