# codock.nvim

English | [中文](./README.zh-CN.md)

A Neovim plugin that opens a terminal with Coding Agent CLI tools (crush, opencode, claude, gemini-cli, etc.) in a vertical split.

![Preview](./resources/Preview.gif)

## 1. Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'gitsang/codock.nvim',
  opts = {
    width = 80, -- Width of the vertical split
    codock_cmd = "pi", -- Command to run in the terminal (pi, opencode, claude, codex, etc.)
    copy_to_clipboard = false, -- Copy to system clipboard
    actions = {},
  },
  cmd = { "Codock", "CodockFilePosPaste", "CodockFilePosYank", "CodockActions" },
  keys = {
      { "<leader>CCO", "<cmd>Codock opencode<cr>", desc = "Open Opencode", mode = { "n", "v" } },
      { "<leader>CCC", "<cmd>Codock claude<cr>", desc = "Open Claude", mode = { "n", "v" } },
      { "<leader>CCX", "<cmd>Codock codex<cr>", desc = "Open Codex", mode = { "n", "v" } },
      { "<leader>CCP", "<cmd>Codock pi<cr>", desc = "Open Pi Agent", mode = { "n", "v" } },
      { "<leader>CCD", "<cmd>Codock dsh --profile tui<cr>", desc = "Open Deepseek Harness TUI", mode = { "n", "v" } },
      { "<leader>CY", ":'<,'>CodockFilePosYank<cr>", desc = "Copy file position", mode = { "n", "v" } },
      { "<leader>CP", ":'<,'>CodockFilePosPaste<cr>", desc = "Copy and paste file position", mode = { "n", "v" } },
      { "<leader>CA", ":'<,'>CodockActions<cr>", desc = "Run Codock actions", mode = { "n", "v" } },
  },
}
```

## 2. Usage

After installation, you can run the following commands:

### 2.1 Codock Command

Run the `:Codock` command to open a terminal in a vertical split running the configured AI CLI command. The terminal starts in the git project root when available; otherwise it starts in the current working directory.

You can also specify a different CLI tool as an argument:

- `:Codock` - Open the default CLI tool configured in `codock_cmd`
- `:Codock claude` - Open claude
- `:Codock opencode` - Open opencode
- `:Codock gemini-cli` - Open gemini-cli

### 2.2 CodockFilePosPaste and CodockFilePosYank Commands

- `:CodockFilePosPaste [prefix]` copies the relative file path and line/column information, then sends it to the AI CLI tool. For example, `:CodockFilePosPaste @` copies and sends `@path/to/file.lua:L1`.
- `:CodockFilePosYank [prefix]` only copies the relative file path and line/column information. For example, `:CodockFilePosYank @` copies `@path/to/file.lua:L1`.
- The optional prefix defaults to an empty string.
- `:CodockFilePos [prefix]` remains as a backward-compatible alias for `:CodockFilePosPaste [prefix]`.

### 2.3 CodockActions Command

The `:CodockActions` command opens a popup selector containing the default and custom actions. The default actions include yanking and pasting file positions; these request an optional prefix through `vim.ui.input()`.

When text needs to be sent to a terminal (for example, `CodockFilePosPaste` and Actions), it goes to the most recently focused codock terminal; if none exists, one is opened automatically.

You can find how to define prompt and executable actions in [Custom Actions Tutorial](docs/actions.md).

## 3. Supported AI CLI Tools

This plugin supports various AI CLI tools:

- `crush` - [Crush CLI](https://github.com/charmbracelet/crush)
- `opencode` - OpenCode
- `claude` - Claude Code
- `gemini-cli` - Gemini CLI

Simply set the `codock_cmd` option to your preferred AI CLI tool.

## 4. FAQ

### 4.1 Temporarily Disable Auto-Scroll to Bottom

The codock terminal automatically scrolls to the bottom when it loses focus, so it keeps following the latest output (Neovim only tails terminal output while the terminal cursor is on the last line). If you want to browse the terminal output without it jumping to the bottom, disable this behavior temporarily:

```vim
:autocmd! codock_nvim WinLeave
:autocmd! codock_nvim TermLeave
```

Or via Lua:

```lua
vim.api.nvim_clear_autocmds({ group = "codock_nvim", event = { "WinLeave", "TermLeave" } })
```

> The scroll-to-bottom behavior is registered on both the `WinLeave` and `TermLeave` events, so both must be removed. The other autocmd (`WinEnter` → `startinsert`) is unaffected.

Restart Neovim to re-enable it — the `codock_nvim` augroup is recreated with `clear = true` in `setup()` on every start.
