# ~/.zshrc  (lives in ~/dotfiles/zsh, linked by stow)
# Plain-English guide to everything here: ~/dotfiles/zsh/SHELL-CHEATSHEET.md

# --- fastfetch greeting --------------------------------------------------------
# Only in a normal kitty window: not the dropdown terminal (DROPTERM), not inside
# Neovim's terminal (NVIM), not over SSH, not in nested shells.
if [[ -o interactive && -n $KITTY_WINDOW_ID && -z $DROPTERM && -z $NVIM \
      && -z $SSH_CONNECTION && $SHLVL -eq 1 ]]; then
  fastfetch
fi

# --- PATH ----------------------------------------------------------------------
# Programs installed with `cargo install` (Rust) land in ~/.cargo/bin
typeset -U path
path=("$HOME/.cargo/bin" $path)

# --- Oh My Zsh -----------------------------------------------------------------
# Cloned at a pinned commit by install.sh (no auto-updates: update by bumping the
# commit in install.sh).
export ZSH="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"
ZSH_CUSTOM="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh-custom"
ZSH_THEME=""                       # prompt comes from starship instead
zstyle ':omz:update' mode disabled
DISABLE_AUTO_TITLE="false"
ZSH_DISABLE_COMPFIX="true"         # skip the slow permission audit of completion dirs
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
mkdir -p "${ZSH_COMPDUMP:h}"

# fzf: use fd to list files, bat to preview them, palette colors
source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/fzf-colors.zsh"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline --color=$FZF_COLORS"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons=always {}'"

# zsh-syntax-highlighting must stay last
# (colored-man-pages is in the brief; MANPAGER=bat below does the colouring in practice)
plugins=(git sudo fzf zoxide extract colored-man-pages zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# --- History -------------------------------------------------------------------
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"
HISTSIZE=50000
SAVEHIST=50000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

# --- Keys ----------------------------------------------------------------------
# ALT shortcuts belong to Hyprland, so word movement uses Ctrl.
bindkey '^[[1;5D' backward-word        # Ctrl + Left
bindkey '^[[1;5C' forward-word         # Ctrl + Right
bindkey '^H'      backward-kill-word   # Ctrl + Backspace (kitty sends ^H)
bindkey '^[[3;5~' kill-word            # Ctrl + Delete
bindkey '^[[H'    beginning-of-line    # Home
bindkey '^[[F'    end-of-line          # End
bindkey '^[[3~'   delete-char          # Delete

ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# --- Tools ---------------------------------------------------------------------
export EDITOR=nvim
export VISUAL=nvim
# Man pages through bat (syntax-colored)
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/aliases.zsh"

# Prompt (last, so nothing above overrides it)
eval "$(starship init zsh)"
