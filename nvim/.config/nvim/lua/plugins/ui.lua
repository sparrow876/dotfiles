-- Status line, buffer tabs, key hints, icons.
return {
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Status line at the bottom (mode, file, git branch, errors, position)
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "nord",
        globalstatus = true,
        component_separators = "│",
        section_separators = { left = "", right = "" },
      },
    },
  },

  -- Open files as tabs at the top. Shift + h / l to switch.
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          always_show_bufferline = false,
          offsets = { { filetype = "neo-tree", text = "Files", separator = true } },
        },
        highlights = require("nord.plugins.bufferline").akinsho(),
      })
    end,
  },

  -- Press Space (or any prefix) and wait: a popup lists what you can type next
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>f", group = "find (Telescope)" },
        { "<leader>g", group = "git" },
        { "<leader>l", group = "LaTeX" },
        { "<leader>c", group = "code" },
        { "<leader>b", group = "buffer" },
      },
    },
  },
}
