-- LaTeX with vimtex: continuous compile with latexmk, PDF in zathura (opens
-- beside kitty), SyncTeX both ways (Ctrl + click in zathura jumps to the line).
--   Space l l  start/stop continuous compile    Space l v  show this spot in the PDF
--   Space l e  list errors                      Space l c  clean aux files
return {
  "lervag/vimtex",
  lazy = false, -- vimtex must not be lazy-loaded (it's cheap; loads per .tex file)
  init = function()
    vim.g.vimtex_view_method = "zathura_simple" -- plain "zathura" needs xdotool (X11 only)
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_quickfix_mode = 0 -- don't jump into the error list on every save
    vim.g.vimtex_mappings_enabled = 0 -- use the Space l … keys below instead
  end,
  keys = {
    { "<leader>ll", "<cmd>VimtexCompile<cr>", desc = "Compile (toggle continuous)", ft = "tex" },
    { "<leader>lv", "<cmd>VimtexView<cr>", desc = "View in zathura", ft = "tex" },
    { "<leader>le", "<cmd>VimtexErrors<cr>", desc = "Show errors", ft = "tex" },
    { "<leader>lc", "<cmd>VimtexClean<cr>", desc = "Clean aux files", ft = "tex" },
    { "<leader>lt", "<cmd>VimtexTocToggle<cr>", desc = "Table of contents", ft = "tex" },
  },
}
