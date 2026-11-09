#!/usr/bin/env bash
# Dotfiles installer. Run from anywhere; it locates the repo itself.
#
#   ./install.sh               user-level setup only (no sudo):
#                                dirs, pinned clones, theme render, stow, gsettings
#   ./install.sh --packages    install packages/pacman.txt + packages/aur.txt
#                                (asks for your sudo password via pacman/yay)
#   ./install.sh --all         --packages, then the user-level setup
#   ./install.sh --only <step> run one step: dirs | clones | render | stow | gsettings
#
# It never enables services, edits /etc or runs third-party scripts.
# Root-level steps live in system/ROOT-STEPS.md and are run by hand.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BACKUP_DIR="$HOME/.local/state/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# Stow packages that are finished and safe to link. Each build step adds its
# package here once it is complete, so a half-built config never replaces a
# working one (e.g. `hypr` is only added once step 2 is done).
STOW_PACKAGES=(
  hypr        # step 2
  kitty       # step 3
  zsh
  starship
  fastfetch
  lazygit
  bat
  quickshell  # step 4
)

# Third-party code, cloned at a pinned commit. Nothing here is executed.
#   name | url | commit | destination
CLONES=(
  "oh-my-zsh|https://github.com/ohmyzsh/ohmyzsh.git|cca3bdfbef8c52ef8939ce7911ff68852b949daa|$DATA_HOME/oh-my-zsh"
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git|85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5|$DATA_HOME/oh-my-zsh-custom/plugins/zsh-autosuggestions"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git|e6683f20e5c38d3e5447f45845d04ddda75d0f23|$DATA_HOME/oh-my-zsh-custom/plugins/zsh-syntax-highlighting"
  "qylock|https://github.com/Darkkal44/qylock.git|c2933f27b655a999911e6699e1b2c67e59cbd428|$HOME/.local/src/qylock"
)

# ~/.config/<dir> entries that are shared with other software: never move the
# whole directory, only back up individual conflicting files.
SHARED_DIRS=(".config/systemd" ".config/environment.d" ".local" ".config/autostart")
# ---------------------------------------------------------------------------

c_blue=$'\e[38;2;127;179;255m'; c_warn=$'\e[38;2;242;198;109m'; c_err=$'\e[38;2;239;111;122m'; c_off=$'\e[0m'
info() { printf '%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
warn() { printf '%s==> warning:%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
die()  { printf '%s==> error:%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }

read_list() { sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$1"; }

step_packages() {
  [[ $EUID -ne 0 ]] || die "run as your normal user, not root"
  local multilib=0
  grep -qx multilib < <(pacman-conf --repo-list) && multilib=1
  mapfile -t pkgs < <(read_list "$REPO/packages/pacman.txt")
  if ((!multilib)); then
    warn "multilib is not enabled: skipping steam and lib32-* (see ROOT-STEPS.md)"
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | grep -vE '^(steam|lib32-.*)$')
  fi
  info "Installing ${#pkgs[@]} repo packages (pacman will ask to confirm)"
  sudo pacman -S --needed "${pkgs[@]}"

  mapfile -t aur < <(read_list "$REPO/packages/aur.txt")
  if ((${#aur[@]})); then
    command -v yay >/dev/null || die "yay not found; install it first (ROOT-STEPS.md)"
    info "Installing ${#aur[@]} AUR packages (review each PKGBUILD diff yay shows)"
    yay -S --needed "${aur[@]}"
  fi
}

step_dirs() {
  info "Creating user folders"
  command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update
  # Some of these may already exist as btrfs subvolumes (ROOT-STEPS section 1);
  # mkdir -p leaves existing ones alone.
  mkdir -p "$HOME"/{Music,Documents,Downloads,Pictures,Videos,Desktop,Templates,Public} \
           "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers" \
           "$HOME/Videos/Recordings" "$HOME/GoogleDrive" \
           "$HOME/.local/src" "$HOME/.local/bin" "$HOME/.cache/wallpaper-thumbs"
}

clone_pinned() {
  local name="$1" url="$2" commit="$3" dest="$4"
  if [[ -d $dest/.git ]]; then
    local current_url
    current_url="$(git -C "$dest" remote get-url origin)"
    [[ $current_url == "$url" ]] || die "$dest points at $current_url, expected $url"
    if [[ $(git -C "$dest" rev-parse HEAD) == "$commit" ]]; then
      info "$name already at ${commit:0:10}"
      return
    fi
    git -C "$dest" fetch --quiet origin
  elif [[ -e $dest ]]; then
    die "$dest exists but is not a git clone; move it away and re-run"
  else
    info "Cloning $name"
    mkdir -p "$(dirname "$dest")"
    git clone --quiet --no-checkout "$url" "$dest"
  fi
  git -C "$dest" -c advice.detachedHead=false checkout --quiet "$commit"
  info "$name pinned at ${commit:0:10}"
}

step_clones() {
  local entry
  for entry in "${CLONES[@]}"; do
    IFS='|' read -r name url commit dest <<<"$entry"
    clone_pinned "$name" "$url" "$commit" "$dest"
  done
}

step_render() {
  info "Rendering theme files from theme/palette.toml"
  "$REPO/theme/render.sh" >/dev/null
}

is_shared() {
  local p
  for p in "${SHARED_DIRS[@]}"; do [[ $1 == "$p" || $1 == "$p"/* ]] && return 0; done
  return 1
}

backup() {
  local rel="$1"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$HOME/$rel" "$BACKUP_DIR/$rel"
  warn "backed up ~/$rel -> ${BACKUP_DIR/#$HOME/\~}/$rel"
}

# Move anything in $HOME that would block stow out of the way.
#  - ~/.config/<app> real directories (e.g. an old ~/.config/hypr) are moved whole,
#    so old leftovers can't be sourced by accident.
#  - inside shared dirs, only the individual conflicting files are moved.
prepare_targets() {
  local pkg="$1" f rel top
  while IFS= read -r -d '' f; do
    rel="${f#"$REPO/$pkg"/}"
    if [[ $rel == .config/* ]]; then
      top=".config/$(cut -d/ -f2 <<<"$rel")"
      if ! is_shared "$top" && [[ -d $HOME/$top && ! -L $HOME/$top ]] \
         && [[ $(readlink -f "$HOME/$top") != "$REPO"/* ]]; then
        # Only move it if it contains something that isn't already our symlink.
        if find "$HOME/$top" -mindepth 1 \( -type f -o -type l \) -print0 |
           while IFS= read -r -d '' t; do [[ $(readlink -f "$t") == "$REPO"/* ]] || exit 1; done; then
          :
        else
          backup "$top"
          continue
        fi
      fi
    fi
    if [[ -e $HOME/$rel || -L $HOME/$rel ]] && [[ $(readlink -f "$HOME/$rel") != "$REPO/$pkg/$rel" ]]; then
      [[ -d $HOME/$rel && ! -L $HOME/$rel ]] && continue  # stow descends into real dirs
      backup "$rel"
    fi
  done < <(find "$REPO/$pkg" -mindepth 1 \( -type f -o -type l \) ! -name .gitkeep -print0)
}

step_stow() {
  command -v stow >/dev/null || die "stow not installed (install.sh --packages)"
  if ((${#STOW_PACKAGES[@]} == 0)); then
    info "No stow packages enabled yet (they are added as each build step finishes)"
    return
  fi
  local pkg
  for pkg in "${STOW_PACKAGES[@]}"; do
    [[ -d $REPO/$pkg ]] || die "stow package '$pkg' missing"
    prepare_targets "$pkg"
    stow --dir="$REPO" --target="$HOME" --ignore='\.gitkeep' --restow "$pkg"
    info "linked $pkg"
  done
  # bat reads custom themes from a cache; rebuild it so the generated "rice" theme is found
  if command -v bat >/dev/null && [[ -d $HOME/.config/bat/themes ]]; then
    bat cache --build >/dev/null && info "rebuilt bat theme cache"
  fi
}

step_gsettings() {
  if ! command -v gsettings >/dev/null || [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
    warn "no gsettings/session bus (e.g. on a TTY); re-run '--only gsettings' inside Hyprland"
    return
  fi
  info "Applying GNOME/GTK settings"
  local s=org.gnome.desktop.interface
  gsettings set $s color-scheme 'prefer-dark'
  gsettings set $s gtk-theme 'Adwaita-dark'
  gsettings set $s icon-theme 'Papirus-Dark'
  gsettings set $s cursor-theme 'Bibata-Modern-Ice'
  gsettings set $s cursor-size 24
  # Text sizes match Windows at 125% (see theme/palette.toml font_pt)
  gsettings set $s font-name 'Noto Sans 11.25'
  gsettings set $s document-font-name 'Noto Sans 12'
  gsettings set $s monospace-font-name 'JetBrainsMono Nerd Font 11.25'
}

user_setup() {
  step_dirs
  step_clones
  step_render
  step_stow
  step_gsettings
  info "Done. Anything moved aside is in ${BACKUP_DIR/#$HOME/\~} (if it exists)."
}

case "${1:-}" in
  "")          user_setup ;;
  --packages)  step_packages ;;
  --all)       step_packages; user_setup ;;
  --only)      [[ -n ${2:-} ]] && declare -F "step_$2" >/dev/null || die "unknown step '${2:-}'"
               "step_$2" ;;
  -h|--help)   sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)           die "unknown option '$1' (try --help)" ;;
esac
