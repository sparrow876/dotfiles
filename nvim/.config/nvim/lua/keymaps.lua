-- Your own shortcuts (plugin shortcuts live in their lua/plugins/*.lua file).
-- <leader> = Space. Press Space and wait: which-key lists everything.
local map = function(mode, keys, action, desc)
  vim.keymap.set(mode, keys, action, { desc = desc, silent = true })
end

-- Files
map("n", "<leader>w", "<cmd>write<cr>", "Save file")
map("n", "<leader>q", "<cmd>quit<cr>", "Quit window")
map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")

-- Splits: Space v / Space s / Space x
map("n", "<leader>v", "<cmd>vsplit<cr>", "Split vertically")
map("n", "<leader>s", "<cmd>split<cr>", "Split horizontally")
map("n", "<leader>x", "<cmd>close<cr>", "Close this split")

-- Move between splits with Ctrl + h/j/k/l
map("n", "<C-h>", "<C-w>h", "Go to left split")
map("n", "<C-j>", "<C-w>j", "Go to lower split")
map("n", "<C-k>", "<C-w>k", "Go to upper split")
map("n", "<C-l>", "<C-w>l", "Go to right split")

-- Resize splits with Ctrl + arrows
map("n", "<C-Up>", "<cmd>resize +2<cr>", "Taller split")
map("n", "<C-Down>", "<cmd>resize -2<cr>", "Shorter split")
map("n", "<C-Left>", "<cmd>vertical resize -4<cr>", "Narrower split")
map("n", "<C-Right>", "<cmd>vertical resize +4<cr>", "Wider split")

-- Buffers (open files, shown as tabs at the top): Shift + h / l
map("n", "<S-h>", "<cmd>bprevious<cr>", "Previous buffer")
map("n", "<S-l>", "<cmd>bnext<cr>", "Next buffer")
map("n", "<leader>bd", "<cmd>bdelete<cr>", "Close buffer")

-- Keep the selection when indenting in visual mode
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")

-- Diagnostics (errors/warnings)
map("n", "<leader>d", vim.diagnostic.open_float, "Show the error under the cursor")
