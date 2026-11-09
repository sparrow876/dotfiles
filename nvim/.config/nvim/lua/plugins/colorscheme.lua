-- Nord colorscheme (gbprod/nord.nvim), solid background (not transparent):
-- Neovim stays Nord whatever desktop theme is active.
return {
  "gbprod/nord.nvim",
  lazy = false,
  priority = 1000, -- load before everything else
  config = function()
    require("nord").setup({
      transparent = false,
      terminal_colors = true,
      diff = { mode = "bg" },
      borders = true,
      errors = { mode = "bg" },
    })
    vim.cmd.colorscheme("nord")
  end,
}
