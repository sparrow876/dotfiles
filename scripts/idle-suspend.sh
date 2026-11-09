#!/usr/bin/env bash
# Suspend after a long idle, but ONLY on battery, never when plugged in.
# Called by hypridle (hypr/.config/hypr/hypridle.conf):
#   idle-suspend.sh start   at 20 min idle: suspend now if on battery, otherwise
#                           keep checking every 30 s while you stay idle (so
#                           unplugging the charger later still suspends)
#   idle-suspend.sh stop    on any input: stop checking
# "On battery" = the battery reports Discharging. That covers both chargers on
# this laptop (the barrel jack ADP1 and USB-C power delivery).
set -u
pidfile="${XDG_RUNTIME_DIR:-/tmp}/idle-suspend.pid"

on_battery() {
  local bat
  for bat in /sys/class/power_supply/BAT*; do
    [[ $(cat "$bat/status" 2>/dev/null) == Discharging ]] && return 0
  done
  return 1
}

case "${1:-}" in
  start)
    echo $$ > "$pidfile"
    sleeper=
    trap '[[ -n $sleeper ]] && kill "$sleeper" 2>/dev/null; exit 0' TERM INT
    while true; do
      if on_battery; then
        rm -f "$pidfile"
        exec systemctl suspend
      fi
      sleep 30 & sleeper=$!
      wait "$sleeper"
    done
    ;;
  stop)
    if [[ -f $pidfile ]]; then
      pid=$(<"$pidfile")
      # only kill it if that pid is still this script (pids get reused)
      grep -qa idle-suspend "/proc/$pid/cmdline" 2>/dev/null && kill "$pid" 2>/dev/null
      rm -f "$pidfile"
    fi
    ;;
  *)
    echo "usage: $0 start|stop" >&2
    exit 2
    ;;
esac
