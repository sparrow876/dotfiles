#!/usr/bin/env bash
# One-time setup for `ccmonitor` (Claude Code Usage Monitor,
# github.com/Maciek-roboblog/Claude-Code-Usage-Monitor, MIT): a live terminal
# view of your Claude Code token use, cost and limits.
# You run this yourself (it installs third-party code); no root needed.
#
# What it does:
#   1. creates ~/.local/share/ccmonitor/venv (a Python venv; nothing else on
#      the system changes)
#   2. installs requirements.txt with pip --require-hashes: 16 small packages,
#      each must match its pinned SHA-256, wheels only (nothing compiled),
#      ~25 MB from pypi.org
# The `ccmonitor` command (~/.local/bin, from this repo) runs it from there.
#
# What ccmonitor reads/writes when it runs (source reviewed 2026-11-18, v4.0.0):
#   reads  ~/.claude/projects/**/*.jsonl  (Claude Code's local session logs)
#   writes ~/.claude-monitor/             (its settings, cache, logs)
#   network: none by default. Only with --api does it read your Claude login
#   token (~/.claude/.credentials.json) and send it to api.anthropic.com
#   (Anthropic's own, undocumented usage endpoint). Don't pass --api if you
#   don't want that.
#
# Re-run any time (starts from a fresh venv). Undo:
#   rm -rf ~/.local/share/ccmonitor ~/.claude-monitor
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
venv="${XDG_DATA_HOME:-$HOME/.local/share}/ccmonitor/venv"

echo "==> Creating $venv"
rm -rf -- "$venv"
mkdir -p -- "$(dirname "$venv")"
python3 -m venv "$venv"

echo "==> Installing pinned packages (hash-checked, wheels only)"
"$venv/bin/pip" install --disable-pip-version-check --no-deps --only-binary=:all: \
  --require-hashes -r "$here/requirements.txt"

"$venv/bin/ccmonitor" --version
echo "Done. Run: ccmonitor   (Ctrl + C quits; ccmonitor --help for options)"
