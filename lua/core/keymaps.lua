local runner = require("core.runner")
local checker = require("core.compiler_check")
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

map("n", "<F5>", runner.run_current, { desc = "Build/Run current file" })
map("n", "<F6>", runner.build_current, { desc = "Build current file" })
map("n", "<leader>rr", runner.run_current, { desc = "Build/Run current file" })
map("n", "<leader>rb", runner.build_current, { desc = "Build current file" })
map("n", "<leader>ri", runner.run_with_input, { desc = "Run current file with input redirection" })

map("n", "gl", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<F7>", checker.check_current, { desc = "Check current file with g++/gcc" })
map("n", "<leader>rc", checker.check_current, { desc = "Check current file with g++/gcc" })
