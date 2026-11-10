#!/usr/bin/env bash
# Update the whole system, carefully. Alias: `update`.
#   1. Arch Linux news since your last update. If an item asks for MANUAL
#      INTERVENTION for a package you have, it stops so you can read it first
#      (or ask Claude: `cd ~/dotfiles && claude`, "explain the Arch news").
#   2. What will be upgraded (official repos + AUR), with a heads-up for the
#      packages that matter most here (kernel, NVIDIA, Hyprland, Quickshell...).
#   3. `yay -Syu`: you confirm in yay as usual (and read AUR PKGBUILD diffs).
#      snap-pac takes a btrfs snapshot before and after, automatically.
#   4. Afterwards: reboot / log-out hint, Hyprland config check, config files
#      to merge (.pacnew), unneeded packages, packages missing from this repo's
#      lists, failed services, firmware updates.
# Nothing is changed without you confirming in yay. Safe to run any time.
#   update           the whole thing
#   update --check   everything except the upgrade itself (changes nothing)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
PACLOG=/var/log/pacman.log
mkdir -p "$STATE"

# Standard terminal colors, so the active theme's kitty palette applies
b=$'\e[1m'; dim=$'\e[2m'; off=$'\e[0m'
blue=$'\e[34m'; yellow=$'\e[33m'; red=$'\e[31m'; green=$'\e[32m'
section() { printf '\n%s%s==> %s%s\n' "$b" "$blue" "$*" "$off"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$off" "$*"; }
note() { printf '  %s\n' "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$off" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$red" "$off" "$*"; }
# ask "question" -> 0 only if the answer is y/yes (default no)
ask()  { local a; read -r -p "  $1 [y/N] " a; [[ ${a,,} == y || ${a,,} == yes ]]; }

CHECK=0
case "${1:-}" in
  "")        ;;
  --check)   CHECK=1 ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)         echo "usage: update [--check]" >&2; exit 2 ;;
esac

[[ $EUID -eq 0 ]] && { bad "Run this as your normal user (yay asks for sudo itself)."; exit 1; }
AUR=yay; command -v yay >/dev/null || AUR=paru
command -v "$AUR" >/dev/null || { bad "No AUR helper (yay) found."; exit 1; }

# Packages whose updates deserve attention on this system: pattern | what to know
WATCH=(
  '^linux(-headers)?$ :: reboot afterwards (new kernel)'
  '^(lib32-)?nvidia :: reboot afterwards (NVIDIA driver)'
  '^(linux-firmware.*|intel-ucode|mesa|lib32-mesa|vulkan-intel|systemd|glibc)$ :: reboot afterwards'
  '^(hyprland|aquamarine|hyprutils|hyprlang|hyprgraphics|hyprcursor|xdg-desktop-portal-hyprland|hypridle)$ :: Hyprland: config syntax can change between versions'
  '^(quickshell|qt6-base|qt6-declarative|qt6-wayland)$ :: Quickshell/Qt: the bar and panels can break'
  '^(sddm|qt6-svg|qt6-multimedia)$ :: login / lock screen'
  '^(pipewire|wireplumber|pipewire-.*)$ :: audio'
)
watch_note() {  # $1 = package name -> prints the note if it's on the watch list
  local w; for w in "${WATCH[@]}"; do [[ $1 =~ ${w%% :: *} ]] && { printf '%s' "${w#* :: }"; return 0; }; done; return 1
}

# ---------------------------------------------------------------------------
# What's pending (also used by the news check below)
repo=$(checkupdates 2>/dev/null); rc=$?
aur=$("$AUR" -Qua 2>/dev/null)
all=$(printf '%s\n%s\n' "$repo" "$aur" | sed '/^$/d')

section "Arch Linux news"
# Last full upgrade that actually finished ("starting" alone may have been aborted)
last_upgrade=$(awk '/starting full system upgrade/ { s = substr($1, 2, length($1) - 2) }
                    /\[ALPM\] transaction completed/ && s { last = s; s = "" }
                    END { print last }' "$PACLOG" 2>/dev/null)
PENDING="$(awk '{print $1}' <<<"$all" | paste -sd' ')" python3 -I - "${last_upgrade:-}" <<'PY'
import sys, re, os, html, subprocess, urllib.request, email.utils, datetime
import xml.etree.ElementTree as ET

B, DIM, OFF, Y, R = "\033[1m", "\033[2m", "\033[0m", "\033[33m", "\033[31m"
since = None
if sys.argv[1]:
    try:
        since = datetime.datetime.fromisoformat(sys.argv[1])
    except ValueError:
        pass
try:
    with urllib.request.urlopen("https://archlinux.org/feeds/news/", timeout=15) as r:
        root = ET.fromstring(r.read())
except Exception as e:
    print(f"  {Y}!{OFF} Couldn't download the news ({e.__class__.__name__}). Check https://archlinux.org/news/ yourself.")
    sys.exit(20)

def run(*cmd):
    return set(subprocess.run(cmd, capture_output=True, text=True).stdout.split())
installed = run("pacman", "-Qq")
known = installed | run("pacman", "-Slq")

items = []
for it in root.iter("item"):
    title = (it.findtext("title") or "").strip()
    date = email.utils.parsedate_to_datetime(it.findtext("pubDate"))
    body = re.sub(r"<[^>]+>", " ", html.unescape(it.findtext("description") or ""))
    # package names in the title ("Arch Linux" is not a package mention)
    words = re.findall(r"[a-z0-9][a-z0-9+._-]*[a-z0-9+]", re.sub(r"arch linux", " ", title.lower()))
    common = {"file", "which", "less", "time", "patch", "make", "screen", "dialog", "man",
              "update", "default", "new", "now", "all", "users", "and", "the", "for", "with"}
    mentioned = [w for w in words if w in known and w not in common]
    have = [w for w in mentioned if w in installed]
    manual = bool(re.search(r"manual(ly)? intervention|requires? manual", title + " " + body, re.I))
    items.append((date, title, it.findtext("link"), manual, have, mentioned))

new = [i for i in items if since is None or i[0] > since]
if since is None:
    new = items[:5]
    print(f"  {DIM}(no full update in pacman.log yet: showing the 5 newest){OFF}")
# Also: recent manual-intervention items about a package that is about to update,
# even if they're older than the last upgrade (e.g. that upgrade skipped it)
pending = set(os.environ.get("PENDING", "").split())
recent = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=14)
new += [i for i in items if i not in new and i[3] and i[0] > recent and set(i[5]) & pending]
if not new:
    d, t = items[0][0], items[0][1]
    print(f"  Nothing new since your last update ({since:%d %b %Y}). Newest: {d:%d %b} · {t}")
    sys.exit(0)

stop = False
for date, title, link, manual, have, mentioned in new[:10]:
    tag = ""
    if manual and (have or not mentioned):
        tag, stop = f" {R}{B}[MANUAL INTERVENTION · you have {', '.join(have) or 'it?'}]{OFF}", True
    elif manual:
        tag = f" {DIM}[manual step, but not for a package you have]{OFF}"
    elif have:
        tag = f" {DIM}[you have {', '.join(have)}]{OFF}"
    print(f"  {date:%d %b %Y} · {B}{title}{OFF}{tag}\n    {DIM}{link}{OFF}")
sys.exit(10 if stop else 0)
PY
case $? in
  0)  ;;
  10) printf '\n'
      warn "${b}Read the item(s) marked MANUAL INTERVENTION before updating.${off}"
      note "Not sure what it means for you? Run ${b}claude${off} in ~/dotfiles and ask it to explain."
      ((CHECK)) || ask "Have you read it and want to update anyway?" || { note "Stopped. Nothing was changed."; exit 0; } ;;
  *)  ((CHECK)) || ask "Update without having seen the news?" || { note "Stopped. Nothing was changed."; exit 0; } ;;
esac

# ---------------------------------------------------------------------------
section "Available updates"
[[ $rc -eq 1 ]] && warn "Couldn't check the official repos (offline?)."
if [[ -z $all ]]; then
  ok "Everything is up to date."
else
  others=()
  while read -r pkg old _ new; do
    if n=$(watch_note "$pkg"); then
      printf '  %s!%s %-28s %s → %s  %s(%s)%s\n' "$yellow" "$off" "$pkg" "$old" "$new" "$dim" "$n" "$off"
    else
      others+=("$pkg")
    fi
  done <<<"$all"
  if ((${#others[@]})); then
    note "${#others[@]} other package(s):"
    printf '%s\n' "${others[@]}" | column -c "$(( $(tput cols 2>/dev/null || echo 100) - 4 ))" | sed 's/^/    /'
  fi
  [[ -n $aur ]] && note "${dim}AUR: yay shows each PKGBUILD diff; if unsure, answer N there and ask Claude to review it.${off}"
  free=$(df -B1G --output=avail / | tail -1 | tr -d ' ')
  (( free < 5 )) && warn "Only ${free} GB free on /. Snapshots need room; clean up first if the update is big."

  if ((CHECK)); then
    note "${dim}(check only: nothing was upgraded; run ${b}update${off}${dim} to install these)${off}"
  else
    section "Upgrading ($AUR -Syu)"
    note "${dim}A snapshot is taken automatically before and after (snap-pac).${off}"
    logpos=$(wc -l < "$PACLOG")
    snap_before=$(snapper -c root list 2>/dev/null | awk -F'│' '$1+0 > n {n=$1+0} END {print n+0}')
    "$AUR" -Syu; rc=$?
    ((rc != 0)) && warn "$AUR stopped (exit $rc). Anything it already did is in /var/log/pacman.log."

    upgraded=$(tail -n +"$((logpos + 1))" "$PACLOG" | sed -nE 's/.*\[ALPM\] upgraded ([^ ]+) \((.*)\)$/\1 \2/p')
    if [[ -n $upgraded ]]; then
      section "What changed"
      ok "$(wc -l <<<"$upgraded") package(s) upgraded."
      reboot=() relog=() verify_hypr=0
      while read -r pkg _; do
        n=$(watch_note "$pkg") || continue
        case $n in
          reboot*)    reboot+=("$pkg") ;;
          Hyprland*)  relog+=("$pkg"); verify_hypr=1 ;;
          Quickshell*|login*|audio) relog+=("$pkg") ;;
        esac
      done <<<"$upgraded"
      if ((verify_hypr)) && command -v Hyprland >/dev/null; then
        if out=$(Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" 2>&1); then
          ok "Hyprland config still valid with the new version."
        else
          bad "Hyprland reports config errors with the new version:"
          printf '%s\n' "$out" | tail -8 | sed 's/^/      /'
          note "Ask Claude to fix it before logging out (cd ~/dotfiles && claude)."
        fi
      fi
      # the snapshot taken before this update (for rolling back)
      pre=$(snapper -c root list 2>/dev/null | awk -F'│' -v b="${snap_before:-0}" '$2 ~ /pre/ && $1+0 > b && !f {f=$1+0} END {if (f) print f}')
      [[ -n $pre ]] && note "${dim}Snapshot from before this update: #$pre (rolling back: system/ROOT-STEPS.md §1.6).${off}"
      printf '%s  %s package(s): %s\n' "$(date '+%F %T')" "$(wc -l <<<"$upgraded")" \
        "$(awk '{print $1}' <<<"$upgraded" | paste -sd' ' | cut -c1-400)" >> "$STATE/update.log"
    fi
  fi   # CHECK
fi

# ---------------------------------------------------------------------------
section "Housekeeping"
pacnew=$(pacdiff -o 2>/dev/null)
if [[ -n $pacnew ]]; then
  warn "Config files with a new version to merge (.pacnew / .pacsave):"
  sed 's/^/      /' <<<"$pacnew"
  note "Merge them: ${b}sudo DIFFPROG='nvim -d' pacdiff${off} (or ask Claude to go through them)."
else
  ok "No .pacnew / .pacsave files."
fi

orphans=$(pacman -Qdtq 2>/dev/null)
if [[ -n $orphans ]]; then
  warn "Packages nothing needs any more: $(paste -sd' ' <<<"$orphans")"
  note "Remove them: ${b}sudo pacman -Rns \$(pacman -Qdtq)${off}"
else
  ok "No unneeded packages."
fi

# Explicitly installed but not in packages/*.txt -> a fresh install would miss them
mapfile -t listed < <(sed 's/#.*//' "$REPO"/packages/{pacman,aur,base}.txt 2>/dev/null | tr -s ' \t' '\n' | sed '/^$/d')
extra=()
while read -r p; do
  hit=0; for l in "${listed[@]}"; do [[ $p == $l ]] && { hit=1; break; }; done   # $l unquoted: globs like xorg-*
  ((hit)) || extra+=("$p")
done < <(pacman -Qqe)
if ((${#extra[@]})); then
  warn "Installed by hand, not in ~/dotfiles/packages: ${extra[*]}"
  note "Tell Claude to add them to the package lists (or remove them), so a fresh install matches."
else
  ok "Package lists match what's installed."
fi

failed=$( { systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain; } 2>/dev/null | awk '{print $1}')
if [[ -n $failed ]]; then
  warn "Failed services: $(paste -sd' ' <<<"$failed")  (details: systemctl status <name>)"
else
  ok "No failed services."
fi

if command -v fwupdmgr >/dev/null; then
  fwupdmgr refresh >/dev/null 2>&1   # quietly skips if the metadata is recent
  fw=$(fwupdmgr get-updates --no-unreported-check --no-metadata-check --no-reboot-check 2>&1)
  if grep -qiE 'no updat|no upgrades|No updatable' <<<"$fw"; then
    ok "No firmware updates (fwupd). HP BIOS updates that fwupd doesn't offer need HP's own updater."
  elif ! grep -qE '^[├└]|New version' <<<"$fw"; then
    note "Couldn't check firmware (fwupd): $(tail -1 <<<"$fw")"
  else
    warn "Firmware updates available:"
    grep -E '^[├└]|New version|Summary' <<<"$fw" | head -12 | sed 's/^/      /'
    note "Install: ${b}fwupdmgr update${off} (may reboot into the update; keep the charger plugged in)."
  fi
fi

# ---------------------------------------------------------------------------
if [[ -n ${upgraded:-} ]]; then
  section "Next"
  if ((${#reboot[@]})); then
    warn "${b}Reboot${off} to start using: ${reboot[*]}"
  elif ((${#relog[@]})); then
    warn "${b}Log out and back in${off} (ALT + Escape → Logout) to start using: ${relog[*]}"
  else
    ok "Nothing to restart."
  fi
  note "${dim}Something broken after this? Run claude in ~/dotfiles: it checks pacman.log + MAINTENANCE.md.${off}"
fi
printf '\n'
