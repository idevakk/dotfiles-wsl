#!/usr/bin/env bash
# WSL npm wrapper: preloads the IPv6/Happy-Eyeballs fix before npm.
# Node ≥20's autoSelectFamily tries IPv6 first, which hangs under WSL's
# NAT DNS (AAAA records resolve but IPv6 routes are unreachable).
# Pi's `npmCommand` setting points here so that `pi install` works.
#
# The preload script (wsl-npm-asf-fix.js) calls:
#   net.setDefaultAutoSelectFamily(false)
# which makes Node skip the IPv6 attempt and connect over IPv4 immediately.
set -euo pipefail

PRELOAD="$HOME/.dotfiles-wsl/wsl-npm-asf-fix.js"
NPM_BIN="$(command -v npm)"

if [ ! -f "$PRELOAD" ]; then
  echo "wsl-npm-wrapper: preload not found at $PRELOAD" >&2
  exit 1
fi

exec node --require="$PRELOAD" "$NPM_BIN" "$@"
