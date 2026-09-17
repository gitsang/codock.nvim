local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

local function fail(message)
	error(message, 0)
end

local function assert_true(condition, message)
	if not condition then
		fail(message)
	end
end

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		fail(string.format("%s: expected %s, got %s", message, vim.inspect(expected), vim.inspect(actual)))
	end
end

local utils = require("codock.utils")
local open_path = require("codock.open_path")

-- Setup ---------------------------------------------------------------------

local tmp_dir = root .. "/.tmp_codock_open_path_test"
vim.fn.mkdir(tmp_dir .. "/src/nested", "p")
local target_file = tmp_dir .. "/src/nested/target.lua"
vim.fn.writefile({ "line1", "line2", "line3", "line4", "line5" }, target_file)

local command = string.format(
	"sh -c 'printf \"HEAD src/nested/target.lua:3:2 TAIL\\n\"; sleep 5'"
)

require("codock").setup({
	width = 40,
	codock_cmd = command,
	copy_to_clipboard = false,
})

-- Path parsing ---------------------------------------------------------------

local clicked = utils.parse_file_path_at("see src/nested/target.lua:3:2 done", 8)
assert_true(clicked ~= nil, "Parser should find a path in terminal output")
assert_equal(clicked.path, "src/nested/target.lua", "Parser should return the path")
assert_equal(clicked.line, 3, "Parser should return the line")
assert_equal(clicked.col, 2, "Parser should return the column")

local with_line = utils.parse_file_path_at("see src/nested/target.lua:12 done", 8)
assert_equal(with_line.line, 12, "Parser should return a line-only suffix")
assert_equal(with_line.col, nil, "Parser should not invent a column")

local trailing_dot = utils.parse_file_path_at("see src/nested/target.lua. done", 8)
assert_equal(trailing_dot.path, "src/nested/target.lua", "Parser should drop prose punctuation")

assert_true(
	utils.parse_file_path_at("see src/nested/target.lua done", 4) == nil,
	"Parser should ignore clicks on whitespace between tokens"
)
assert_true(
	utils.resolve_file_path("see", tmp_dir) == nil,
	"Words that are not files must not resolve"
)

-- Path resolution ------------------------------------------------------------

---Resolver bound to a specific base directory, as `open_path` does for the
---terminal it was clicked in.
---@param base_cwd string
---@return fun(path: string): string|nil
local function resolve_from(base_cwd)
	return function(path)
		return utils.resolve_file_path(path, base_cwd)
	end
end

assert_equal(
	utils.resolve_file_path("src/nested/target.lua", tmp_dir),
	vim.fn.fnamemodify(target_file, ":p"),
	"Resolver should resolve relative to the terminal cwd"
)
assert_true(
	utils.resolve_file_path("src/nested/missing.lua", tmp_dir) == nil,
	"Resolver should reject missing files"
)
assert_true(
	utils.resolve_file_path("src/nested", tmp_dir) == nil,
	"Resolver should reject directories"
)

-- Window selection -----------------------------------------------------------

-- Open the file in a real window so there is an editor window to target.
vim.cmd("edit " .. vim.fn.fnameescape(target_file))
local file_win = vim.api.nvim_get_current_win()

vim.cmd("Codock")
local term_buf = vim.api.nvim_get_current_buf()
local term_win = vim.api.nvim_get_current_win()
assert_true(utils.is_codock_terminal(term_buf), "Codock did not open a terminal buffer")

local other_file = tmp_dir .. "/src/other.lua"
vim.fn.writefile({ "other" }, other_file)
vim.cmd("stopinsert")

-- `open_file_at` opens in the given window while the terminal keeps focus.
assert_true(
	utils.open_file_at(file_win, other_file, 1, nil),
	"Opening a file in another window should succeed"
)
assert_equal(
	vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(file_win)),
	other_file,
	"Target window should show the opened file"
)

-- Clicks on non-terminal windows are not handled (they keep native behavior).
assert_true(
	utils.find_file_window(term_win) == file_win,
	"File window lookup should prefer the editor window next to the terminal"
)

-- Mouse handling -------------------------------------------------------------

-- A click that does not land on an existing file must report "not handled" so
-- the caller can replay the native click.
local parsed_missing = utils.resolve_file_path("src/nested/nope.lua", tmp_dir)
assert_true(parsed_missing == nil, "Missing files must not be handled")

-- Out-of-range positions are clamped instead of raising.
assert_true(
	utils.open_file_at(file_win, target_file, 999, 500),
	"Out-of-range positions should still open"
)
assert_equal(vim.api.nvim_win_get_cursor(file_win)[1], 5, "Line should be clamped to the last line")

-- A missing position lands on line 1.
assert_true(
	utils.open_file_at(file_win, target_file, nil, nil),
	"Opening without a position should succeed"
)
assert_equal(vim.api.nvim_win_get_cursor(file_win)[1], 1, "Opening without a position should use line 1")

-- An invalid window is reported rather than raising.
assert_true(
	not utils.open_file_at(123456, target_file, 1, nil),
	"Invalid windows should return false"
)

-- Opening in a split --------------------------------------------------------

-- `open_file_in_split` gives the file a window of its own, so the buffer the
-- anchor window displays is left alone and focus stays where it was.
local split_one = tmp_dir .. "/src/split_one.lua"
local split_two = tmp_dir .. "/src/split_two.lua"
vim.fn.writefile({ "one", "two", "three" }, split_one)
vim.fn.writefile({ "a", "b" }, split_two)

local anchor_win = file_win
local anchor_buf = vim.api.nvim_win_get_buf(anchor_win)
local windows_before = #vim.api.nvim_tabpage_list_wins(0)
local current_before = vim.api.nvim_get_current_win()

local new_win = utils.open_file_in_split(term_win, anchor_win, split_one, 2, 1)
assert_true(new_win ~= nil, "Opening in a split should create a window")
assert_equal(
	#vim.api.nvim_tabpage_list_wins(0),
	windows_before + 1,
	"Opening in a split should add exactly one window"
)
assert_equal(
	vim.api.nvim_win_get_buf(anchor_win),
	anchor_buf,
	"The anchor window must keep the buffer it was showing"
)
assert_equal(
	vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(new_win)),
	vim.fn.fnamemodify(split_one, ":p"),
	"The new window should show the opened file"
)
assert_equal(
	vim.api.nvim_win_get_cursor(new_win)[1],
	2,
	"The new window should use the requested line"
)
assert_equal(
	vim.api.nvim_get_current_win(),
	current_before,
	"Opening in a split must not change the current window"
)

-- A file that is already on screen is reused instead of split again.
local reused = utils.open_file_in_split(term_win, anchor_win, split_one, 3, nil)
assert_equal(reused, new_win, "An already visible file should reuse its window")
assert_equal(
	#vim.api.nvim_tabpage_list_wins(0),
	windows_before + 1,
	"Reusing a window must not add another one"
)
assert_equal(
	vim.api.nvim_win_get_cursor(new_win)[1],
	3,
	"The reused window should move to the new line"
)

-- A different file gets a window of its own.
local second_win = utils.open_file_in_split(term_win, anchor_win, split_two, nil, nil)
assert_true(second_win ~= nil and second_win ~= new_win, "A new file should get a new window")
assert_equal(
	#vim.api.nvim_tabpage_list_wins(0),
	windows_before + 2,
	"A new file should add exactly one window"
)
assert_equal(
	vim.api.nvim_win_get_buf(anchor_win),
	anchor_buf,
	"The anchor window must still keep its buffer"
)

-- An invalid anchor is reported instead of raising.
local split_three = tmp_dir .. "/src/split_three.lua"
vim.fn.writefile({ "x" }, split_three)
assert_true(
	utils.open_file_in_split(term_win, 123456, split_three, 1, nil) == nil,
	"An invalid anchor window should return nil"
)

-- `find_window_showing` finds the window that displays a buffer.
assert_equal(
	utils.find_window_showing(vim.api.nvim_win_get_buf(new_win)),
	new_win,
	"The window showing a buffer should be found"
)
assert_true(
	utils.find_window_showing(term_buf) == term_win,
	"The terminal window shows its own buffer"
)

-- A plain terminal window must never be used as a file target, otherwise its
-- buffer would be replaced by the opened file.
vim.cmd("vsplit")
local plain_term_win = vim.api.nvim_get_current_win()
vim.cmd("enew")
vim.fn.jobstart({ "cat" }, { term = true })
assert_equal(
	vim.api.nvim_get_option_value("buftype", { buf = vim.api.nvim_get_current_buf() }),
	"terminal",
	"Expected a plain terminal buffer"
)
vim.cmd("vsplit")
vim.cmd("enew")
local editor_win = vim.api.nvim_get_current_win()

local chosen = utils.find_file_window(plain_term_win)
assert_equal(chosen, editor_win, "A plain terminal window must not become the file target")

-- Non-ASCII file names in terminal output are matched as well.
local cjk = utils.parse_file_path_at("修改 中文目录/文件.lua:3:2 完成", 8)
assert_true(cjk ~= nil, "Parser should match non-ASCII file names")
assert_equal(cjk.path, "中文目录/文件.lua", "Parser should return the non-ASCII path")
assert_equal(cjk.line, 3, "Parser should return the line for a non-ASCII path")

-- Line-range and GitHub-style suffixes keep their line numbers.
local range = utils.parse_file_path_at("changed src/nested/target.lua:2-4 now", 12, resolve)
assert_equal(range.line, 2, "A `:start-end` range should use its start line")
assert_equal(range.path, "src/nested/target.lua", "A `:start-end` range should strip the range")

local github = utils.parse_file_path_at("changed src/nested/target.lua#L3 now", 12, resolve)
assert_equal(github.line, 3, "A `#L3` suffix should set the line")
assert_equal(github.path, "src/nested/target.lua", "A `#L3` suffix should be stripped")

-- grep/ripgrep print `path:line:col:text`; the trailing text must be ignored.
local grep_match = utils.parse_file_path_at("src/nested/target.lua:3:2:local x = 1", 12, resolve)
assert_equal(grep_match.path, "src/nested/target.lua", "A grep match should resolve the path")
assert_equal(grep_match.line, 3, "A grep match should resolve the line")
assert_equal(grep_match.col, 2, "A grep match should resolve the column")

local grep_no_col = utils.parse_file_path_at("src/nested/target.lua:3:local x = 1", 12, resolve)
assert_equal(grep_no_col.path, "src/nested/target.lua", "`path:line:text` should resolve the path")
assert_equal(grep_no_col.line, 3, "`path:line:text` should resolve the line")

-- Git diff headers carry an `a/` or `b/` prefix that is not a real directory.
assert_equal(
	utils.resolve_file_path("b/src/nested/target.lua", tmp_dir),
	vim.fn.fnamemodify(target_file, ":p"),
	"A git diff `b/` prefix should be resolved away"
)
assert_equal(
	utils.resolve_file_path("a/src/nested/target.lua", tmp_dir),
	vim.fn.fnamemodify(target_file, ":p"),
	"A git diff `a/` prefix should be resolved away"
)

-- File names containing characters that are also common in prose are matched
-- only because the wider candidate exists on disk.
local spaced_file = tmp_dir .. "/my file.lua"
vim.fn.writefile({ "spaced" }, spaced_file)
local spaced = utils.parse_file_path_at("changed my file.lua now", 10, resolve_from(tmp_dir))
assert_true(spaced ~= nil, "A file name with a space should be matched")
assert_equal(spaced.path, "my file.lua", "A file name with a space should keep the whole name")

local paren_file = tmp_dir .. "/src/a(1).lua"
vim.fn.writefile({ "paren" }, paren_file)
local parens = utils.parse_file_path_at("changed src/a(1).lua now", 12, resolve_from(tmp_dir))
assert_equal(parens.path, "src/a(1).lua", "A file name with parentheses should be matched")

-- Prose must still not be treated as a file name.
for _, prose in ipairs({ "changed something here now", "run npm install", "see also the docs" }) do
	for col = 1, #prose do
		assert_true(
			utils.parse_file_path_at(prose, col, resolve_from(tmp_dir)) == nil,
			"Prose should not be matched: " .. prose
		)
	end
end

vim.fn.delete(tmp_dir, "rf")
print("codock opens clicked file paths in the editor window")
vim.cmd("qa!")
