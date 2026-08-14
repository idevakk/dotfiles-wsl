#!/usr/bin/env bash
# npm wrapper: preloads the IPv6/Happy-Eyeballs fix before the real npm.
# Node ≥20's autoSelectFamily tries IPv6 first, which hangs on hosts where
# AAAA records resolve but there is no routable IPv6 path (WSL NAT DNS,
# many plain VPS/containers): npm hangs on connect and eventually
# ETIMEDOUT. This wrapper finds the *real* npm on $PATH (never itself,
# whatever name/ location it is installed under), then execs node with the
# preload required.
#
# The preload script (wsl-npm-asf-fix.js) calls:
#   net.setDefaultAutoSelectFamily(false)
#   dns.setDefaultResultOrder("ipv4first")
# which makes Node skip the IPv6 attempt and connect over IPv4 immediately.
set -euo pipefail

PRELOAD="$HOME/.dotfiles-wsl/wsl-npm-asf-fix.js"
REAL_NPM=""

# Scan $PATH for a real npm binary, skipping wrapper copies so this script
# never recurses into itself regardless of the name/location it is installed
# under (e.g. as `npm` in ~/.local/bin on a server it shadows the real npm on
# PATH). A candidate is a wrapper copy — skipped — if it references the unique
# preload filename `wsl-npm-asf-fix.js`; this also covers stale duplicate
# copies of older wrapper versions left by earlier installs, which a plain
# resolved-path comparison would not detect. The real npm never contains that
# string.
if command -v npm >/dev/null 2>&1; then
  IFS=':' read -r -a _paths <<< "$PATH"
  for _dir in "${_paths[@]}"; do
    [ -n "$_dir" ] || _dir="."
    _cand="$_dir/npm"
    if [ -x "$_cand" ] && ! grep -q 'wsl-npm-asf-fix' "$_cand" 2>/dev/null; then
      REAL_NPM="$(readlink -f "$_cand")"
      break
    fi
  done
fi

if [ -z "$REAL_NPM" ]; then
  echo "wsl-npm-wrapper: could not find the real npm on PATH (only this wrapper?)" >&2
  exit 1
fi

if [ ! -f "$PRELOAD" ]; then
  echo "wsl-npm-wrapper: preload not found at $PRELOAD" >&2
  exit 1
fi

exec node --require="$PRELOAD" "$REAL_NPM" "$@"