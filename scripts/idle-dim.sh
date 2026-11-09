#!/usr/bin/env bash
# Called by hypridle. dim: save brightness, dim to 30% of it, show the idle
# screen. restore: put brightness back, hide the idle screen.
case "${1:-}" in
  dim)
    cur=$(brightnessctl g)
    brightnessctl -q -s set $(( cur * 30 / 100 > 1 ? cur * 30 / 100 : 1 ))
    qs ipc call idlescreen enter >/dev/null 2>&1 ;;
  restore)
    brightnessctl -q -r
    qs ipc call idlescreen leave >/dev/null 2>&1 ;;
esac
