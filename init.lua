vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Optional MSYS2 overrides:
vim.g.msys2_root = "C:/msys64"
vim.g.msys2_env = "mingw64"

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

require("core.msys2").setup()
require("core.options")
require("core.autocmds")
require("core.keymaps")
require("core.templates").setup()
require("core.competitive").setup()

require("lazy").setup("plugins", {
  change_detection = { notify = false },
  install = {
    colorscheme = { "tokyonight", "habamax" },
  },
  ui = {
    border = "rounded",
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
