# Shell cheat sheet

Your terminal is **kitty** running **zsh**. Oh My Zsh adds plugins, **starship** draws
the prompt, and a handful of modern tools replace the classic commands.
Everything is configured in `~/dotfiles/zsh/.zshrc` and `~/dotfiles/zsh/.config/zsh/aliases.zsh`.

The classic command is always still there: put `command` in front, e.g. `command ls`.

---

## The prompt (starship)

```
dotfiles  main ?1 ❯
```
- **Blue folder name**: where you are (shortened to the last 3 folders).
- ** main**: the git branch, if you're inside a git repo. Symbols after it show
  the git state: `?` new files, `!` changed files, `+` staged, `⇡`/`⇣` ahead/behind.
- **` 3s`** (yellow): how long the last command took, only shown if over 2 seconds.
- **`❯`** is blue normally and **red if the last command failed**.

## Keys in the terminal

| Keys | What it does |
|------|--------------|
| `Ctrl + ←` / `Ctrl + →` | Jump one word left / right |
| `Ctrl + Backspace` | Delete the word before the cursor |
| `Ctrl + Delete` | Delete the word after the cursor |
| `→` (right arrow) or `End` | Accept the grey suggestion (autosuggestions) |
| `Ctrl + R` | Fuzzy-search your command history (fzf) |
| `Ctrl + T` | Fuzzy-pick a file and paste its path (with preview) |
| `Esc` `Esc` | Put `sudo` in front of the current/last command (sudo plugin) |
| `Tab` | Complete commands, files, git branches… |
| `Ctrl + Shift + C` / `V` | Copy / paste in kitty |
| `Ctrl + Shift + +` / `-` | Bigger / smaller text in kitty |
| `` ALT + ` `` | Show / hide the dropdown terminal |

Note: ALT shortcuts belong to Hyprland, so the shell uses Ctrl instead.

---

## The tools

### eza: `ls` with icons and git status
Lists files with icons, folders first.
```sh
ls            # list files
ll            # detailed list: size, date, git status per file
la            # same, including hidden files (starting with .)
lt            # tree view, 2 levels deep
lt --level=4  # deeper tree
```

### bat: `cat` with syntax highlighting
Shows a file with colors and line numbers. `cat` runs bat for you.
```sh
cat install.sh            # colored, no pager
bat install.sh            # colored, scrollable (q to quit)
bat -A file.txt           # show invisible characters (tabs, line endings)
```
Man pages also open in bat, so `man rsync` is colored.

### ripgrep (`rg`): search text inside files
Searches every file below the current folder, very fast, skips `.git` and ignored files.
```sh
rg "gaps_out"             # find a word in all files here
rg -i hyprland            # ignore upper/lower case
rg -t lua "hl.bind"       # only in .lua files
rg -l TODO                # only list file names
```

### fd: find files by name
Like `find`, but simpler and faster.
```sh
fd keybinds               # files whose name contains "keybinds"
fd -e lua                 # all .lua files
fd -H zshrc               # include hidden files
fd -t d wallpaper         # only folders
```

### fzf: fuzzy finder
Type a few letters in any order and it narrows the list down.
- **`Ctrl + R`**: search everything you've typed before, Enter puts it on the prompt.
- **`Ctrl + T`**: pick a file (with a preview); its path is inserted where your cursor is.
- **`Alt + C`** would cd into a folder, but ALT is Hyprland's key, so use `z` (below) instead.
```sh
nvim $(fzf)               # pick a file, open it in Neovim
```

### zoxide (`z`): jump to folders you use often
It learns which folders you visit. Type part of the name instead of the full path.
```sh
z dotfiles                # jumps to ~/dotfiles (once you've been there before)
z hypr conf               # best match containing "hypr" then "conf"
zi                        # pick from a list (with fzf)
z -                       # back to the previous folder
```

### lazygit (`lg`): git in a friendly full-screen UI
Run `lg` inside a git repo. Arrow keys / `h j k l` move between panels, `space` stages
a file, `c` commits, `P` pushes, `p` pulls, `?` shows all keys, `q` quits.

### extract: unpack any archive
```sh
extract photos.zip        # also .tar.gz, .tar.xz, .7z, .rar, .zst, ...
```

### fastfetch
The system summary that greets you in a new kitty window (not in the dropdown
terminal, Neovim's terminal or over SSH). Run `fastfetch` any time to see it again.

### Rust: cargo and rustup
`cargo` builds and runs Rust projects; `rustup` installs and updates Rust itself.
```sh
cargo new hello && cd hello   # new project (Cargo.toml + src/main.rs)
cargo run                     # build and run it
cargo build --release         # optimised build, in target/release/
cargo clippy                  # extra hints about your code
cargo fmt                     # format all files (Neovim also does this on save)
cargo install ripgrep         # install a Rust program into ~/.cargo/bin (on PATH)
rustup update                 # update Rust to the newest stable version
```

---

## Handy aliases

| Alias | Runs |
|-------|------|
| `ls` `ll` `la` `lt` | eza variants (above) |
| `cat` | `bat --paging=never` |
| `lg` | `lazygit` |
| `..` / `...` | go up one / two folders |
| `dots` | `cd ~/dotfiles` |
| `update` | update the whole system safely (below) |

### `update`: keeping the system up to date

Run `update` about once a week. It shows the Arch Linux news first and **stops
if a news item needs a manual step for something you have** (ask Claude to
explain it), lists what will change, then runs `yay -Syu` (confirm with Enter;
a snapshot is taken automatically before and after). Afterwards it tells you
whether to reboot or log out, and checks config files, unneeded packages,
failed services and firmware.

`update --check` does all of that except the upgrade itself (changes nothing).

Git aliases from Oh My Zsh's git plugin, the most useful ones:

| Alias | Runs |
|-------|------|
| `gst` | `git status` |
| `ga .` | `git add .` |
| `gcmsg "msg"` | `git commit -m "msg"` |
| `gp` / `gl` | `git push` / `git pull` |
| `glog` | short graph log |
| `gd` | `git diff` |

Full list: `alias | grep git`.
