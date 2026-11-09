-- Git: changed lines in the gutter (gitsigns) and lazygit in a floating window.
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local map = function(keys, fn, desc) vim.keymap.set("n", keys, fn, { buffer = buf, desc = desc }) end
        map("]h", function() gs.nav_hunk("next") end, "Next change")
        map("[h", function() gs.nav_hunk("prev") end, "Previous change")
        map("<leader>gp", gs.preview_hunk, "Preview change")
        map("<leader>gb", gs.blame_line, "Who changed this line")
        map("<leader>gr", gs.reset_hunk, "Undo this change")
      end,
    },
  },
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitCurrentFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = { { "<leader>gg", "<cmd>LazyGit<cr>", desc = "lazygit (floating)" } },
    init = function()
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_floating_window_use_plenary = 0
    end,
  },
}
