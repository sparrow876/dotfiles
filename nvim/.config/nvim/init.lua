-- Neovim entry point. Read top to bottom:
--   lua/options.lua   editor settings (line numbers, tabs, search, ...)
--   lua/keymaps.lua   your own shortcuts (Space is the leader key)
--   lua/autocmds.lua  automatic actions (kitty opacity, highlights, ...)
--   lua/plugins/*.lua one file per group of plugins (loaded by lazy.nvim)
-- Cheat sheet: ~/dotfiles/nvim/CHEATSHEET.md  (or press Space and wait)

-- Leader keys must be set before plugins load
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("options")
require("keymaps")
require("autocmds")

-- lazy.nvim: the plugin manager. Downloads itself on the very first start.
-- Plugin versions are pinned in lazy-lock.json (committed to the repo);
-- update with :Lazy update, then commit the new lazy-lock.json.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "nord" } },
  checker = { enabled = false },          -- no background update checks
  change_detection = { notify = false },  -- reload config quietly when you edit it
  rocks = { enabled = false },            -- no luarocks needed
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin", "netrwPlugin" } },
  },
})
