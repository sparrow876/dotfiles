#!/usr/bin/env bash
# Screen recording is run by Quickshell (services/Recorder.qml) so the bar
# always shows the true state. This is a shortcut for the terminal:
#   record.sh full | region | replay | replay-toggle | mic | status
case "${1:-status}" in
  full)          exec qs ipc call recorder toggleFull ;;
  region)        exec qs ipc call recorder toggleRegion ;;
  replay)        exec qs ipc call recorder replay ;;
  replay-toggle) exec qs ipc call recorder toggleReplay ;;
  mic)           exec qs ipc call recorder toggleMic ;;
  status)        exec qs ipc call recorder status ;;
  *) echo "usage: $0 full|region|replay|replay-toggle|mic|status" >&2; exit 2 ;;
esac
