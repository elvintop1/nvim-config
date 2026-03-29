return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },

  {
  "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    opts = function()
      local function git_branch()
        local head = vim.b.gitsigns_head
        if head and head ~= "" then
          return " " .. head
        end
        return ""
      end

      local function has_git_branch()
        return git_branch() ~= ""
      end

      local function python_env()
        local env = vim.env.VIRTUAL_ENV or vim.env.CONDA_DEFAULT_ENV or vim.env.CONDA_PREFIX
        if env and env ~= "" then
          return " " .. vim.fn.fnamemodify(env, ":t")
        end

        local root = vim.fs.root(0, { "pyproject.toml", "requirements.txt", "setup.py", ".git" })
        if not root then
          return ""
        end

        for _, name in ipairs({ ".venv", "venv", "env", "sim-env" }) do
          if vim.uv.fs_stat(root .. "/" .. name .. "/pyvenv.cfg") then
            return " " .. name
          end
        end

        return ""
      end

      local function has_python_env()
        return python_env() ~= ""
      end

      return {
        options = {
          theme = "tokyonight",
          globalstatus = true,
          section_separators = { left = "", right = "" },
          component_separators = { left = "│", right = "│" },
          disabled_filetypes = {
            statusline = { "alpha" },
          },
        },

        sections = {
          lualine_a = {
            {
              "mode",
              icon = "",
              separator = { left = "" },
              padding = { left = 1, right = 1 },
            },
          },

          lualine_b = {
            {
              git_branch,
              cond = has_git_branch,
              color = { gui = "bold" },
            },
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
              cond = has_git_branch,
            },
          },

          lualine_c = {
            {
              "filename",
              path = 1,
              newfile_status = true,
              symbols = {
                modified = " ●",
                readonly = " ",
                unnamed = "[No Name]",
                newfile = " [New]",
              },
            },
          },

          lualine_x = {
            {
              python_env,
              cond = has_python_env,
              color = { gui = "bold" },
            },
            {
              "diagnostics",
              sources = { "nvim_diagnostic" },
              symbols = {
                error = " ",
                warn  = " ",
                info  = " ",
                hint  = "󰌵 ",
              },
            },
            {
              "filetype",
              colored = true,
              icon_only = false,
            },
          },

          lualine_y = {
            {
              "progress",
              padding = { left = 1, right = 1 },
            },
          },

          lualine_z = {
            {
              "location",
              separator = { right = "" },
              padding = { left = 1, right = 1 },
            },
          },
        },

        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {
            {
              "filename",
              path = 1,
            },
          },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },

        winbar = {
          lualine_c = {
            {
              "filename",
              path = 1,
              symbols = {
                modified = " ●",
                readonly = " ",
                unnamed = "[No Name]",
              },
            },
          },
        },

        inactive_winbar = {
          lualine_c = {
            {
              "filename",
              path = 0,
            },
          },
        },

        extensions = { "neo-tree", "lazy" },
      }
    end,
  },

  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
      { "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
      { "<leader>bd", "<cmd>bdelete<cr>", desc = "Delete buffer" },
    },
    opts = {
      options = {
        mode = "buffers",
        separator_style = "slant",
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
        show_buffer_close_icons = false,
        show_close_icon = false,
        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorer",
            text_align = "left",
          },
        },
        diagnostics_indicator = function(count, level)
          local icon = level:match("error") and "  " or "  "
          return icon .. count
        end,
      },
    },
  },
}
