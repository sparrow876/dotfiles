#!/usr/bin/env bash
# Connect to a WPA2/WPA3-Enterprise Wi-Fi that uses PEAP + MSCHAPv2 (a username
# and password), e.g. IISc's "iiscwlan" or eduroam. Also started by the Wi-Fi
# menu's "Set up…" button for enterprise networks.
#   wifi-enterprise.sh             iiscwlan
#   wifi-enterprise.sh <ssid>      another PEAP network
# iiscwlan settings (IISc DIGITS Linux guide): PEAP (automatic version), inner
# MSCHAPv2, username = your IISc email (name@iisc.ac.in), password = your IISc
# email password.
# Your username and password are asked here (the password hidden) and handed to
# NetworkManager only: they never go to the screen, a log, this repo or your
# shell history. NetworkManager keeps them in its own root-only connection file.
# No sudo needed (NetworkManager allows the wheel group to add connections).
set -uo pipefail

ssid=${1:-iiscwlan}
b=$'\e[1m'; dim=$'\e[2m'; off=$'\e[0m'; yellow=$'\e[33m'; red=$'\e[31m'; green=$'\e[32m'
say()  { printf '%s\n' "$*"; }
warn() { printf '%s!%s %s\n' "$yellow" "$off" "$*"; }
die()  { printf '%s✗%s %s\n' "$red" "$off" "$*"; read -rp "Press Enter to close. " _; exit 1; }
ask()  { local a; read -r -p "$1 [y/N] " a; [[ ${a,,} == y || ${a,,} == yes ]]; }

iface=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "wifi" {print $1; exit}')
[[ -n $iface ]] || die "No Wi-Fi device found."

say "${b}Set up \"$ssid\"${off} (WPA2/WPA3-Enterprise: PEAP + MSCHAPv2)"
if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
  ask "A saved connection \"$ssid\" exists. Replace it?" || { say "Kept the existing one."; exit 0; }
  nmcli connection delete "$ssid" >/dev/null || die "Couldn't remove the old connection."
fi

hint=""; [[ $ssid == iiscwlan ]] && hint=" (your IISc email, name@iisc.ac.in)"
read -r -p "Username$hint: " identity
[[ -n $identity ]] || die "No username given."
read -r -s -p "Password: " password; printf '\n'
[[ -n $password ]] || die "No password given."

# Server certificate check: without it, a fake access point with the same name
# could capture enough to crack your password offline.
say ""
say "Server certificate (strongly recommended): the network's CA certificate file."
[[ $ssid == iiscwlan ]] && say "${dim}IISc: download it at https://digits.iisc.ac.in/tina/wi-fi-ca (IISc login), then give its path.${off}"
guess=$(find "$HOME/Downloads" -maxdepth 1 -type f \( -iname '*.cer' -o -iname '*.crt' -o -iname '*.pem' -o -iname '*.der' \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
read -r -e -p "CA certificate file${guess:+ [Enter = $guess]} (or 'none'): " ca
[[ -z $ca ]] && ca=$guess
ca=${ca/#\~/$HOME}

args=(type wifi con-name "$ssid" ifname "$iface" ssid "$ssid" connection.autoconnect yes
      wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2
      802-1x.identity "$identity" 802-1x.password-flags 0)
if [[ -n $ca && $ca != none ]]; then
  [[ -f $ca ]] || die "No such file: $ca"
  form=PEM; openssl x509 -in "$ca" -noout 2>/dev/null || form=DER
  info=$(openssl x509 -inform "$form" -in "$ca" -noout -subject -issuer -enddate 2>/dev/null) \
    || die "$ca is not a certificate (PEM or DER)."
  say "${dim}$info${off}"
  # Keep a copy where it won't be cleaned up with Downloads
  dest="$HOME/.local/share/certs/$ssid-ca.pem"
  mkdir -p "${dest%/*}"
  openssl x509 -inform "$form" -in "$ca" -out "$dest" || die "Couldn't save the certificate."
  args+=(802-1x.ca-cert "$dest")
else
  warn "${b}No certificate check${off}: anyone can pretend to be \"$ssid\" and catch your login."
  ask "Continue without it (you can add it later by running this again)?" || { say "Stopped. Nothing was changed."; exit 0; }
fi

# The password is passed straight to nmcli (not echoed, not logged)
if ! nmcli connection add "${args[@]}" 802-1x.password "$password" >/dev/null; then
  unset password; die "NetworkManager refused the settings (see the message above)."
fi
unset password
printf '%s✓%s Saved "%s" (connects automatically when in range).\n' "$green" "$off" "$ssid"

start=$(date '+%F %T')
say "Connecting…"
if nmcli --wait 45 connection up "$ssid" >/dev/null 2>&1; then
  printf '%s✓%s Connected to %s.\n' "$green" "$off" "$ssid"
else
  warn "Couldn't connect. The likely reasons:"
  journalctl -u NetworkManager -u wpa_supplicant --since "$start" --no-pager -o cat 2>/dev/null \
    | grep -iE 'eap|802-1x|auth|cert|reason' | tail -6 | sed 's/^/    /'
  say "  Wrong username/password, or the network rejected the certificate settings."
  say "  Run this again to fix them, or ask Claude (it can read these logs; your password isn't in them)."
fi
# The server's certificate as seen just now (to pin its name later if wanted)
cert=$(journalctl -u wpa_supplicant --since "$start" --no-pager -o cat 2>/dev/null | grep -o "depth=0 subject='[^']*'" | tail -1)
[[ -n $cert ]] && say "${dim}Server certificate: ${cert#depth=0 }${off}"
read -r -p "Press Enter to close. " _
