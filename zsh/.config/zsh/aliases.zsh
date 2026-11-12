# Friendly aliases. The original commands stay reachable with `command`,
# e.g. `command ls`, `command cat`.

# eza: ls with icons and git status
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza -l --icons=auto --group-directories-first --git --time-style=relative'
alias la='eza -la --icons=auto --group-directories-first --git --time-style=relative'
alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
# newest last, like `ls -ltr` (eza's -t takes a field name, so ls -lt doesn't work)
alias lnew='eza -l --sort=modified --icons=auto --git --time-style=relative'

# bat: cat with syntax highlighting (no pager, so it behaves like cat)
alias cat='bat --paging=never'

# lazygit
alias lg='lazygit'

# Small conveniences
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias dots='cd ~/dotfiles'

# System update with Arch news, snapshots and checks (scripts/update.sh)
alias update='~/dotfiles/scripts/update.sh'
