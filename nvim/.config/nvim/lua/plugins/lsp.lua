-- Language servers (errors, go-to-definition, rename, ...) + completion.
-- mason installs the servers; mason-lspconfig enables them automatically.
-- Add a language later: :Mason, press i on a server, restart Neovim.
local servers = { "lua_ls", "texlab", "pyright", "bashls", "marksman" }

return {
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", opts = { ui = { border = "rounded" } } },
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
    },
    config = function()
      -- Every server gets the completion engine's capabilities
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
      -- Lua: know about the `vim` global (for editing this config)
      vim.lsp.config("lua_ls", {
        settings = { Lua = { diagnostics = { globals = { "vim" } }, workspace = { checkThirdParty = false } } },
      })
      require("mason-lspconfig").setup({ ensure_installed = servers, automatic_enable = true })

      vim.diagnostic.config({ virtual_text = true, severity_sort = true, float = { border = "rounded" } })

      -- Shortcuts that only exist when a language server is attached
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("rice-lsp", { clear = true }),
        callback = function(args)
          -- nowait: Neovim 0.12 also has gra/grn/grr/gri, which would make "gr" wait
          local map = function(keys, fn, desc) vim.keymap.set("n", keys, fn, { buffer = args.buf, desc = desc, nowait = true }) end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "Show references")
          map("K", vim.lsp.buf.hover, "Show documentation")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action (quick fix)")
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "Format file")
        end,
      })
    end,
  },

  -- Completion popup while typing. Enter accepts, Tab / Shift+Tab move.
  -- Pure-Lua matcher: no prebuilt binary is downloaded.
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = {
        preset = "enter",
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      completion = { documentation = { auto_show = true }, menu = { border = "rounded" } },
      signature = { enabled = true },
      fuzzy = { implementation = "lua" },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
    },
  },
}
