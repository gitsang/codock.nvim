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
    header = true, -- Show a one-line header with the slot number above each terminal
    open_path_on_click = true, -- Open file paths clicked in the terminal
    follow_output = true, -- Keep unfocused terminals following the latest output
    actions = {},
  },
  cmd = { "Codock", "CodockFilePosPaste", "CodockFilePosYank", "CodockActions", "CodockWidth", "CodockScroll" },
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

## 2. Usage

After installation, you can run the following commands:

### 2.1 Codock Command

The `:Codock` command toggles a codock terminal window in a vertical split. Each terminal is bound to a numbered slot:

- `:Codock` - Toggle slot 1
- `:2:Codock` or `:2Codock` - Toggle slot 2
- `:3:Codock claude` - Toggle slot 3 (runs `claude` when slot 3 is created)

If the slot has no terminal yet, `:Codock` creates one running the configured AI CLI command. The terminal starts in the git project root when available; otherwise it starts in the current working directory. If the slot already has a visible terminal, `:Codock` hides its window. If the slot has a hidden terminal, `:Codock` shows it again in a new split, keeping the same buffer and process.

Counts also work before mappings, so `2<leader>CCP` toggles slot 2 with the `<leader>CCP` mapping shown above.

You can also specify a different CLI tool as an argument when creating a slot:

- `:Codock` - Toggle slot 1 with the default CLI tool configured in `codock_cmd`
- `:Codock claude` - Toggle slot 1 (runs `claude` when slot 1 is created)
- `:2Codock opencode` - Toggle slot 2 (runs `opencode` when slot 2 is created)
- `:2Codock gemini-cli` - Toggle slot 2 (runs `gemini-cli` when slot 2 is created)

> To run a different CLI tool next to an existing terminal, use another slot, e.g. `:2Codock claude`.

Each visible terminal shows a one-line header with its slot number, drawn with the `winbar` option (Neovim 0.11+; on older Neovim the header is simply not shown). The header uses the `CodockHeader` highlight group, which links to `StatusLine` by default, and can be turned off with `header = false`.

### 2.2 CodockFilePosPaste and CodockFilePosYank Commands

- `:CodockFilePosPaste [prefix]` copies the relative file path and line/column information, then sends it to the AI CLI tool. For example, `:CodockFilePosPaste @` copies and sends `@path/to/file.lua:L1`.
- `:CodockFilePosYank [prefix]` only copies the relative file path and line/column information. For example, `:CodockFilePosYank @` copies `@path/to/file.lua:L1`.
- The optional prefix defaults to an empty string.
- `:CodockFilePos [prefix]` remains as a backward-compatible alias for `:CodockFilePosPaste [prefix]`.

### 2.3 CodockActions Command

The `:CodockActions` command opens a popup selector containing the default and custom actions. The default actions include yanking and pasting file positions; these request an optional prefix through `vim.ui.input()`.

When text needs to be sent to a terminal (for example, `CodockFilePosPaste` and Actions), it goes to the most recently focused codock terminal; if that terminal is hidden, its window is shown again first. If no codock terminal exists, one is opened automatically.

You can find how to define prompt and executable actions in [Custom Actions Tutorial](docs/actions.md).

### 2.4 CodockWidth Command

`:CodockWidth [width]` resizes every open codock terminal window to `width`. The new width is also used for terminals opened afterwards.

- `:CodockWidth 30` - resize all codock terminal windows to 30 columns
- `:CodockWidth` - reset all codock terminal windows to the current width

### 2.5 CodockScroll Command

`:CodockScroll` toggles the auto-scroll-to-bottom behavior. By default a codock terminal scrolls back to its latest output when it loses focus (Neovim only tails terminal output while the terminal cursor is on the last line), so a running CLI session keeps following along while you edit elsewhere.

- `:CodockScroll` - toggle the behavior
- `:CodockScroll off` - leave the viewport where you put it (browse scrollback while the CLI keeps printing)
- `:CodockScroll on` - turn it back on
- `:CodockScroll status` - show the current state

The change applies to every existing codock terminal immediately, including terminals that were created while the behavior was off.

> With the behavior off, output produced while the terminal is unfocused is still appended to the buffer — the CLI keeps streaming. Only the viewport stops following it, and it catches up again once the window is focused.

Set the initial value with the `follow_output` option, or run `:CodockScroll off` for a session-only change.

### 2.6 Opening File Paths by Clicking

Clicking a file path in a codock terminal opens it in the editor window next to the terminal, without leaving terminal mode, so the CLI session keeps running. The file is opened like a normal `:edit`: it becomes a listed buffer, so it shows up in the buffer line (and in `:ls`) and the file that was displayed stays one switch away.

Supported formats:

- `src/main.lua` - open the file
- `src/main.lua:42` - open the file and jump to line 42
- `src/main.lua:42:7` - open the file and jump to line 42, column 7
- `src/main.lua:42-50` - a line range, jumps to line 42
- `src/main.lua#L42` - GitHub-style line link
- `src/main.lua:42:7:some text` - a `grep`/ripgrep match, the trailing text is ignored
- `b/src/main.lua` - a git diff path, the `a/` and `b/` prefixes are resolved away

Paths may be wrapped in quotes, backticks, parentheses, brackets or angle brackets, and prose punctuation after the path (as in `see src/main.lua.`) is not treated as part of the name. Absolute paths and `~/` paths work, and a leading `@` (as produced by `:CodockFilePosYank`) is ignored.

Relative paths are resolved against the terminal working directory first and the Neovim working directory second, so paths printed by the CLI resolve correctly even after it changed directory.

> The clicked text must refer to a file that actually exists. A bare file name printed by the CLI (such as `utils.lua` when the file is really at `lua/codock/utils.lua`), a path relative to a directory the CLI knows but Neovim does not, or a path to a directory will not open. Files whose names contain characters that are also common in prose (spaces, parentheses, commas, `#`) are matched too, since a wider candidate is accepted once it resolves to an existing file.

Clicks are only handled when the text under the cursor resolves to an existing file; any other click keeps its normal behavior, including text selection and passing the click through to the CLI.

Disable the feature with:

```lua
opts = {
  open_path_on_click = false,
}
```

## 3. Supported AI CLI Tools

This plugin supports various AI CLI tools:

- `crush` - [Crush CLI](https://github.com/charmbracelet/crush)
- `opencode` - OpenCode
- `claude` - Claude Code
- `gemini-cli` - Gemini CLI

Simply set the `codock_cmd` option to your preferred AI CLI tool.

## 4. FAQ

### 4.1 Auto-Scroll to Bottom

The codock terminal automatically scrolls to the bottom when it loses focus, so it keeps following the latest output (Neovim only tails terminal output while the terminal cursor is on the last line). Toggle it at runtime with `:CodockScroll`:

```vim
:CodockScroll off
:CodockScroll on
:CodockScroll status
```

To start with it disabled, set the option:

```lua
opts = {
  follow_output = false,
}
```

The behavior is implemented with autocmds in the `codock_nvim` augroup, registered on both the `WinLeave` and `TermLeave` events. `:CodockScroll off` removes them for good, including from terminals opened later; `:CodockScroll on` registers them again for every existing codock terminal. The other autocmd (`WinEnter` → `startinsert`) is unaffected.

> Older docs suggested clearing these autocmds by hand (`:autocmd! codock_nvim WinLeave`). `:CodockScroll off` is the supported way now — it also covers terminals created afterwards.

### 4.2 Temporarily Disable Clicking Paths to Open Files

The `<LeftMouse>` mapping that opens file paths is set on each codock terminal buffer. To remove it from the current terminal for a while:

```vim
:silent! tunmap <buffer> <LeftMouse>
:silent! nunmap <buffer> <LeftMouse>
```

Or via Lua:

```lua
pcall(vim.keymap.del, { "n", "t" }, "<LeftMouse>", { buffer = 0 })
```

Restart Neovim or open a new codock terminal to get the mapping back, or disable the feature for good with `open_path_on_click = false`.
