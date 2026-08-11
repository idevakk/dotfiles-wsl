#!/usr/bin/env bash
# dotfiles-wsl helper - peek at a crewmate (or list the fleet).
# Usage:  fm-peek.sh [task-id]    (no arg = list windows + peek each fm-*)
set -euo pipefail
cd ~/firstmate

if [ $# -gt 0 ]; then
  exec bin/fm-peek.sh "$1"
fi

if ! tmux has-session -t firstmate 2>/dev/null; then
  echo "no firstmate session running"; exit 0
fi

tmux list-windows -t firstmate
for w in $(tmux list-windows -t firstmate -F '#{window_name}' 2>/dev/null | grep -E '^fm-'); do
  echo "--- window $w ---"
  bin/fm-peek.sh "${w#fm-}" 2>&1 | tail -8 || true
done