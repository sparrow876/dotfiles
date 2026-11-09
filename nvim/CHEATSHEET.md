# Neovim cheat sheet

Neovim is a keyboard-driven text editor. Start it with `nvim` or `nvim file.txt`.
It's also the default editor for anything that opens one (git commit messages,
`sudoedit`, ...). Config: `~/dotfiles/nvim/.config/nvim/`.

**Space is the "leader" key.** Press Space and wait half a second: a menu
(which-key) pops up listing every shortcut that starts with Space. You don't
need to memorise this page.

---

## 1. The one idea: modes

| Mode | What it's for | How to get there |
|------|---------------|------------------|
| Normal | moving around, giving commands | `Esc` (always safe to press) |
| Insert | typing text | `i` (before cursor), `a` (after), `o` (new line below) |
| Visual | selecting text | `v` (characters), `V` (lines) |
| Command | `:` commands like save/quit | `:` |

The current mode is shown at the bottom left of the status line.

## 2. Survival kit

| Keys | Does |
|------|------|
| `Space w` | save |
| `Space q` | close this window (asks to save if needed) |
| `:qa` Enter | quit everything |
| `u` / `Ctrl + r` | undo / redo (undo history survives closing the file) |
| `Esc` | back to Normal mode, clears search highlight |

## 3. Moving

| Keys | Does |
|------|------|
| `h j k l` or arrows | left, down, up, right |
| `w` / `b` | next / previous word |
| `0` / `$` | start / end of line |
| `gg` / `G` | top / bottom of file |
| `5j` | 5 lines down (the left column shows relative line numbers for this) |
| `/word` Enter, then `n` / `N` | search, next / previous match |
| `%` | jump to the matching bracket |

## 4. Editing (in Normal mode)

| Keys | Does |
|------|------|
| `x` | delete a character |
| `dd` / `yy` / `p` | cut line / copy line / paste (uses the normal clipboard) |
| `dw` / `cw` | delete a word / change a word |
| `ciw` | change the word under the cursor ("change inside word") |
| `ci"` / `ci(` | change text inside quotes / brackets |
| `>` / `<` (in Visual) | indent / unindent the selection |
| `.` | repeat the last change |
| `:%s/old/new/g` Enter | replace everywhere (preview shows live) |

## 5. Files, search, splits

| Keys | Does |
|------|------|
| `Space e` | file tree on the left (Enter opens, `a` add, `d` delete, `r` rename, `?` help) |
| `Space f f` | find a file by name |
| `Space f g` | find text inside all files (ripgrep) |
| `Space f r` | recent files |
| `Space f b` | switch between open files |
| `Space f k` | search all shortcuts |
| `Shift + h` / `Shift + l` | previous / next open file (tabs at the top) |
| `Space b d` | close the current file's tab |
| `Space v` / `Space s` | split side by side / one above the other |
| `Space x` | close this split |
| `Ctrl + h/j/k/l` | move between splits |
| `Ctrl + arrows` | resize the split |
| `Ctrl + \` | floating terminal (press again to hide it, it keeps running) |

In the Telescope finder: type to filter, `Ctrl + j/k` or arrows to move,
Enter to open, `Esc` to close.

## 6. Code help (language servers)

Installed for: Lua, LaTeX (texlab), Python (pyright), Bash, Markdown.
Errors show as coloured text at the end of the line and signs in the gutter.

| Keys | Does |
|------|------|
| `K` | documentation for the thing under the cursor |
| `gd` | go to where it's defined (`Ctrl + o` jumps back) |
| `gr` | list everywhere it's used |
| `Space d` | show the full error message under the cursor |
| `Space c a` | quick fixes for the error |
| `Space c r` | rename everywhere |
| `Space c f` | format the file |

**Completion** pops up while typing: `Tab` / `Shift + Tab` move, `Enter` accepts,
`Esc` closes it.

Add another language: `:Mason`, find the server, press `i`, restart Neovim.

## 7. Git

| Keys | Does |
|------|------|
| `Space g g` | lazygit in a floating window (stage, commit, push; `?` for help, `q` quits) |
| `]h` / `[h` | next / previous changed block |
| `Space g p` | preview what changed here |
| `Space g b` | who last changed this line |
| `Space g r` | undo the change in this block |

Gutter signs: green bar = added, blue = changed, red = deleted.

## 8. LaTeX (vimtex + zathura)

1. `nvim paper.tex`
2. `Space l l` starts **continuous compile** (latexmk). The PDF opens in
   zathura beside the editor and updates every time you save (`Space w`).
   Press `Space l l` again to stop.
3. `Space l v` jumps the PDF to where your cursor is (forward search).
4. **Ctrl + click** in the PDF jumps Neovim to that line (inverse search).
5. `Space l e` lists errors and warnings, `Space l t` shows the table of
   contents, `Space l c` deletes the build files (`.aux`, `.log`, ...).

Zathura keys: `j/k` scroll, `J/K` page, `+/-` zoom, `s` fit width, `a` fit page,
`d` two pages side by side, `Tab` outline, `/` search, **`Ctrl + r` dark mode
for the page**, `q` quit.

Bibliographies with `biblatex` need `biber` (`sudo pacman -S biber`); plain
`\bibliography{}` with BibTeX works out of the box.

## 9. Maintenance

| Command | Does |
|---------|------|
| `:Lazy` | plugin manager: `U` update all, `S` sync to `lazy-lock.json`, `q` close |
| `:Mason` | language servers |
| `:checkhealth` | diagnose problems |
| `:TSUpdate` | update syntax-highlighting parsers |

Plugin versions are pinned in `lazy-lock.json` (in the repo). After `:Lazy`
→ `U`, test, then commit the new `lazy-lock.json`.

Neovim makes kitty fully opaque (including the padding) while it runs and
restores the 80 % transparency when you quit.
