-- File tree on the left. Space e opens/closes it; inside, press ? for help.
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
  keys = { { "<leader>e", "<cmd>Neotree toggle reveal<cr>", desc = "File tree" } },
  opts = {
    close_if_last_window = true,
    filesystem = {
      filtered_items = { hide_dotfiles = false, hide_gitignored = true },
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
    },
    window = { width = 32 },
  },
}
