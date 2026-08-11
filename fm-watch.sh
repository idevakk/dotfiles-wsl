#!/usr/bin/env bash
# dotfiles-wsl helper - watch the fleet (peek without attaching).
# Usage:  fm-watch.sh   (repeat every few seconds, or run inside tmux)
set -euo pipefail
cd ~/firstmate

while true; do
  clear 2>/dev/null || true
  date '+%H:%M:%S'
  bash "$(dirname "$0")/fm-peek.sh"
  sleep 5
done