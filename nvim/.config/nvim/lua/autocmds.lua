-- Things that happen automatically.
local group = vim.api.nvim_create_augroup("rice", { clear = true })
local au = function(events, opts) vim.api.nvim_create_autocmd(events, vim.tbl_extend("force", { group = group }, opts)) end

-- kitty is 80% transparent; Neovim should be fully opaque (including kitty's
-- padding). kitty's remote control (socket only, see kitty.conf) changes the
-- window's background opacity: 1.0 while Neovim runs, back to 0.80 after.
local kitty = vim.env.KITTY_LISTEN_ON
if kitty and kitty ~= "" then
  local function opacity(value, wait)
    local job = vim.system({ "kitty", "@", "--to", kitty, "set-background-opacity", value })
    if wait then job:wait(300) end
  end
  -- kitty's padding uses kitty's own background colour; paint it with the
  -- colorscheme's background so there's no differently coloured frame.
  -- (OSC 11 = set terminal background, OSC 111 = reset it.)
  local function match_padding()
    local bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
    if bg then vim.api.nvim_ui_send(string.format("\027]11;#%06x\027\\", bg)) end
  end
  au({ "VimEnter", "VimResume" }, { callback = function() opacity("1"); match_padding() end })
  au("ColorScheme", { callback = match_padding })
  au({ "VimLeavePre", "VimSuspend" }, {
    callback = function()
      vim.api.nvim_ui_send("\027]111\027\\")
      opacity("0.80", true)
    end,
  })
end

-- Briefly highlight what you just yanked (copied)
au("TextYankPost", { callback = function() vim.hl.on_yank({ timeout = 150 }) end })

-- Prose files wrap at word boundaries
au("FileType", {
  pattern = { "tex", "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})
