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

vim.fn.delete(tmp_dir, "rf")
print("codock opens clicked file paths in the editor window")
vim.cmd("qa!")
