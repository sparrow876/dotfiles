-- Auto-close brackets and quotes (nvim-autopairs), plus $…$ in LaTeX/Markdown.
-- Set up to stay out of the way:
--   * typing ( [ { " gives the closing one too, cursor in between
--   * no pair when the cursor is right before a word ("(|word" stays "(word")
--   * typing the closing ) ] } " $ when it's already next just steps over it
--   * Backspace on an empty pair deletes both; Enter inside {} / [] / () opens
--     an indented block
--   * $ pairs only in tex/markdown, and only where math can start: after a
--     space, the line start or an opening bracket. So "5$", "x$" (closing your
--     own $) and "\$" (a literal dollar) never get an extra $.
--   * in LaTeX, ` and ' are not paired (``quotes'' would fight it)
-- No extra keys are added (fast-wrap's ALT + e would clash with Hyprland).
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    local npairs = require("nvim-autopairs")
    local Rule = require("nvim-autopairs.rule")
    local cond = require("nvim-autopairs.conds")

    npairs.setup({}) -- defaults: skip-over, Backspace and Enter handling as above

    local tex = { "tex", "plaintex" }
    for _, char in ipairs({ "`", "'" }) do
      for _, rule in ipairs(npairs.get_rules(char)) do
        rule.not_filetypes = vim.list_extend(rule.not_filetypes or {}, tex)
      end
    end

    npairs.add_rules({ -- (also re-applies the change above to open buffers)
      Rule("$", "$", { "tex", "plaintex", "markdown" })
        -- only where math starts: line start, a space or ( [ {
        :with_pair(function(o)
          local before = o.line:sub(o.col - 1, o.col - 1)
          if before ~= "" and not before:match("[%s%(%[{]") then return false end
        end)
        -- not right before a word or another $
        :with_pair(cond.not_after_regex("[%w$]"))
        -- typing $ in front of the closing $ steps over it
        :with_move(cond.after_text("$")),
    })
  end,
}
