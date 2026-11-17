-- Formatting (conform.nvim): fixes indentation, spacing and line breaks.
--   Space c f   format the file (Normal mode) or the selected lines (Visual)
-- Rust files are also formatted on every save (like `cargo fmt`).
--
--   C / C++   clang-format   4-space indents, unless the project has its own
--                            .clang-format file (then that file decides)
--   LaTeX     latexindent    4 spaces; no indent.log / backup files
--   Rust      rustfmt        edition read from Cargo.toml
--   Python    ruff format    Black-compatible style
-- Other file types: the language server's formatter if it has one (e.g. Lua).
return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>cf",
      function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
      mode = { "n", "x" },
      desc = "Format file / selection",
    },
  },
  opts = {
    formatters_by_ft = {
      c = { "clang-format" },
      cpp = { "clang-format" },
      tex = { "latexindent" },
      plaintex = { "latexindent" },
      bib = { "latexindent" },
      rust = { "rustfmt" },
      python = { "ruff_format" },
    },
    formatters = {
      ["clang-format"] = {
        prepend_args = function(_, ctx)
          -- a project's .clang-format wins; otherwise LLVM style with 4 spaces
          local found = vim.fs.find({ ".clang-format", "_clang-format" }, { upward = true, path = ctx.dirname })[1]
          return { found and "--style=file" or "--style={BasedOnStyle: LLVM, IndentWidth: 4}" }
        end,
      },
      latexindent = {
        -- -g /dev/null: no indent.log in the folder; -y: indent with 4 spaces, not tabs
        prepend_args = { "-g", "/dev/null", "-y=defaultIndent:'    '" },
      },
    },
    -- Rust only: format on save (the other languages only when you ask)
    format_on_save = function(buf)
      if vim.bo[buf].filetype == "rust" then
        return { timeout_ms = 2000, lsp_format = "fallback" }
      end
    end,
    notify_on_error = true,
  },
}
