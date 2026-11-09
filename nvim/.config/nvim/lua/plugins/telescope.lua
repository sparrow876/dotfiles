-- Telescope: fuzzy finder for files, text, buffers, help. Uses ripgrep + fd.
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }, -- faster sorting (compiled once)
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Find text in files (grep)" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find open buffers" },
    { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Find help" },
    { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Find keymaps" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")
    telescope.setup({
      defaults = {
        -- Ctrl + j / k move through the results (like Ctrl + j / k between splits)
        mappings = {
          i = { ["<C-j>"] = actions.move_selection_next, ["<C-k>"] = actions.move_selection_previous },
        },
        prompt_prefix = "  ",
        selection_caret = " ",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
      },
      pickers = {
        find_files = { find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" } },
      },
    })
    pcall(telescope.load_extension, "fzf")
  end,
}
