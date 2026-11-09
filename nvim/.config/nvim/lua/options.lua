-- Editor settings. `:help 'option'` explains any of them.
local o = vim.opt

o.number = true            -- line numbers
o.relativenumber = true    -- ...relative to the cursor line (great with 5j / 3k)
o.cursorline = true        -- highlight the current line
o.signcolumn = "yes"       -- always show the gutter (git / error signs) so text doesn't jump
o.termguicolors = true     -- full colors
o.mouse = "a"              -- mouse works everywhere
o.clipboard = "unnamedplus" -- yank/paste use the system clipboard (wl-clipboard)

o.tabstop = 4              -- a tab looks 4 spaces wide
o.shiftwidth = 4           -- indent by 4
o.expandtab = true         -- insert spaces, not tabs
o.smartindent = true

o.ignorecase = true        -- search ignores case...
o.smartcase = true         -- ...unless you type a capital letter
o.inccommand = "split"     -- preview :s/find/replace/ live

o.wrap = false             -- long lines don't wrap (LaTeX/Markdown do, see autocmds)
o.scrolloff = 8            -- keep 8 lines visible above/below the cursor
o.sidescrolloff = 8
o.splitright = true        -- new vertical split opens on the right
o.splitbelow = true        -- new horizontal split opens below

o.undofile = true          -- undo history survives closing the file
o.swapfile = false
o.updatetime = 250         -- faster git signs / hover
o.timeoutlen = 400         -- how long to wait for the rest of a shortcut (which-key pops up)
o.confirm = true           -- ask to save instead of refusing to quit
o.showmode = false         -- the mode is shown in the status line instead
o.laststatus = 3           -- one status line for the whole window
o.fillchars = { eob = " " } -- no ~ on empty lines

-- Remote plugins written in Python/Node/Perl/Ruby aren't used: skip looking
-- for them (faster start, fewer :checkhealth warnings).
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
