local msys2 = require("core.msys2").setup()

local function telescope_or_fallback(method)
  local ok, builtin = pcall(require, "telescope.builtin")
  if ok then
    builtin[method]()
    return
  end

  if method == "lsp_definitions" then
    vim.lsp.buf.definition()
  elseif method == "lsp_references" then
    vim.lsp.buf.references()
  elseif method == "lsp_implementations" then
    vim.lsp.buf.implementation()
  end
end

local function with_blink_capabilities(config)
  config = config or {}
  local ok, blink = pcall(require, "blink.cmp")
  if ok and type(blink.get_lsp_capabilities) == "function" then
    config.capabilities = blink.get_lsp_capabilities(config.capabilities)
  end
  return config
end

return {
  {
    "mason-org/mason.nvim",
    lazy = false,
    opts = {},
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local buf = args.buf

          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, {
              buffer = buf,
              silent = true,
              desc = desc,
            })
          end

          map("n", "K", vim.lsp.buf.hover, "Hover")
          map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "gd", function()
            telescope_or_fallback("lsp_definitions")
          end, "Go to definition")
          map("n", "gr", function()
            telescope_or_fallback("lsp_references")
          end, "References")
          map("n", "gi", function()
            telescope_or_fallback("lsp_implementations")
          end, "Implementations")
          map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>f", function()
            vim.lsp.buf.format({ async = true })
          end, "Format buffer")
        end,
      })

      local clangd_cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=iwyu",
      }

      if msys2.IS_WIN and msys2.fs_exists(msys2.gxx) and msys2.fs_exists(msys2.gcc) then
        table.insert(clangd_cmd, "--query-driver=" .. msys2.gxx .. "," .. msys2.gcc)
      elseif msys2.IS_WIN and msys2.fs_exists(msys2.gxx) then
        table.insert(clangd_cmd, "--query-driver=" .. msys2.gxx)
      end

      vim.lsp.config("clangd", with_blink_capabilities({
        cmd = clangd_cmd,
      }))

      vim.lsp.config("basedpyright", with_blink_capabilities({
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              diagnosticMode = "openFilesOnly",
            },
          },
        },
      }))

      vim.lsp.config("ts_ls", with_blink_capabilities({}))

      vim.lsp.config("lua_ls", with_blink_capabilities({
        settings = {
          Lua = {
            completion = {
              callSnippet = "Replace",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              checkThirdParty = false,
            },
          },
        },
      }))

      local r_cmd = vim.fn.exepath("R")
      if r_cmd == "" then
        r_cmd = "R"
      end

      vim.lsp.config("r_language_server", with_blink_capabilities({
        cmd = { r_cmd, "--no-echo", "-e", "languageserver::run()" },
      }))

      vim.lsp.enable("r_language_server")
    end,
  },

  {
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = {
        "basedpyright",
        "clangd",
        "lua_ls",
        "ts_ls",
      },
      automatic_enable = {
        "basedpyright",
        "clangd",
        "lua_ls",
        "ts_ls",
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash",
          "c",
          "cpp",
          "java",
          "javascript",
          "json",
          "lua",
          "python",
          "query",
          "r",
          "regex",
          "vim",
          "vimdoc",
        },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true,
        },
      })
    end,
  },

  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    opts = {
      keymap = {
        preset = "default",
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        ghost_text = {
          enabled = true,
        },
      },
      signature = {
        enabled = true,
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          snippets = {
            opts = {
              search_paths = { vim.fn.stdpath("config") .. "/snippets" },
            },
          },
        },
      },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },
    },
    opts_extend = {
      "sources.default",
    },
  },
}
