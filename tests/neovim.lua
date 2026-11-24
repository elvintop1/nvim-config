vim.g.mapleader = " "
vim.opt.rtp:prepend(vim.fn.getcwd())
local cp = require("core.competitive")
local root = vim.fn.tempname() .. " cp test"
vim.fn.mkdir(root .. "/tools/share", "p")
vim.fn.mkdir(root .. "/problem with spaces", "p")
local prefix = root .. "/tools"
local problem = (vim.uv or vim.loop).fs_realpath(root .. "/problem with spaces")
vim.fn.writefile({ vim.json.encode({ python = "python3", extra_paths = { prefix .. "/bin" } }) }, prefix .. "/config.json")
vim.fn.writefile({ '{"url":"https://codeforces.com/contest/1/problem/A","language":"C++"}' }, problem .. "/.cpw.json")
vim.fn.writefile({ "int main() {}" }, problem .. "/main.cpp")
vim.g.cpw_prefix = prefix
vim.keymap.set("n", "<F5>", "original-runner")
cp.setup()
assert(vim.fn.exists(":CPTest") == 2)
assert(vim.fn.exists(":CPSubmit") == 2)
assert(vim.fn.maparg("<F5>", "n") == "original-runner")
assert(vim.fn.maparg("<Space>pt", "n") ~= "")
vim.cmd("edit " .. vim.fn.fnameescape(problem .. "/main.cpp"))
assert(cp.workspace() == problem, "actual=" .. tostring(cp.workspace()) .. " expected=" .. problem)
local original_window = vim.api.nvim_get_current_win()
local captured
local original_jobstart = vim.fn.jobstart
vim.fn.jobstart = function(argv, opts) captured = { argv = argv, opts = opts }; return 123 end
cp.test(false)
assert(captured.argv[1] == "python3")
assert(captured.argv[2] == prefix .. "/share/cpw.py")
assert(captured.argv[3] == "test")
assert(captured.opts.cwd == problem)
assert(captured.opts.term == true)
vim.api.nvim_set_current_win(original_window)
cp.submit("C++17")
assert(captured.argv[3] == "submit")
assert(captured.argv[4] == problem .. "/main.cpp")
assert(captured.argv[5] == "--language")
assert(captured.argv[6] == "C++17")
vim.fn.jobstart = original_jobstart
vim.fn.delete(root, "rf")
print("Neovim CP commands, keymaps, workspace detection and argv tests passed")
vim.cmd("qa!")
