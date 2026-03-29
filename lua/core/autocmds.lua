local group = vim.api.nvim_create_augroup("UserConfig", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  desc = "Highlight yanked text",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 180 })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  desc = "Restore cursor position",
  callback = function(args)
    local excluded = { commit = true, gitrebase = true }

    if excluded[vim.bo[args.buf].filetype] then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)

    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "c", "cpp", "python", "java", "r" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact", "json", "lua" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "make" },
  callback = function()
    vim.opt_local.expandtab = false
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  group = group,
  desc = "Better terminal defaults",
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.cursorline = false
  end,
})

local checker = require("core.compiler_check")

vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = { "*.c", "*.cc", "*.cpp", "*.cxx", "*.h", "*.hpp" },
  callback = function(args)
    checker.check_buffer(args.buf)
  end,
})
