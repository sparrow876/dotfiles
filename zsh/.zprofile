# zsh login shell. SDDM starts the Hyprland session through it, so the whole
# session (and every app it starts) inherits this.
# ~/.local/bin holds the repo's own commands (bin/: lockdir, unlockdir,
# view-all-images, zathura-glass, ccmonitor) and user installs like claude.
typeset -U path
path=("$HOME/.local/bin" $path)
export PATH
