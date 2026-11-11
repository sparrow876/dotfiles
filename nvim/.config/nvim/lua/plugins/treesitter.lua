-- Treesitter: better syntax highlighting and indentation (main branch API).
-- Parsers are compiled once (needs tree-sitter-cli + a C compiler).
-- LaTeX is left to vimtex's own highlighting, as vimtex recommends.
local parsers = { "lua", "vim", "vimdoc", "query", "bash", "python", "c", "rust",
                  "markdown", "markdown_inline", "json", "toml", "yaml", "bibtex", "diff", "gitcommit" }
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- doesn't support lazy-loading
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install(parsers)
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("rice-treesitter", { clear = true }),
      callback = function(args)
        if vim.bo[args.buf].filetype == "tex" then return end
        if pcall(vim.treesitter.start, args.buf) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
