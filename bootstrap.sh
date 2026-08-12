#!/usr/bin/env bash
# dotfiles-wsl - one-shot WSL agent home installer.
# Reproduces kunchenguid/dotfiles (in bash, no Nix) AND auto-installs the full
# FirstMate-adjacent stack into WSL: jq, neovim, herdr (pinned), treehouse
# (pinned), wezterm/herdr/nvim configs, plus auto-detect of agent CLIs.
# Re-run anytime (idempotent). User-space only: NO sudo required.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="$REPO_DIR/home"
LINK="$HOME/.dotfiles-wsl"
BIN_DIR="$HOME/.local/bin"
FIRSTMATE_DIR="$HOME/firstmate"

mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

[ "$(command -v curl)" ] || { echo "dotfiles-wsl: curl is required" >&2; exit 1; }

say()  { printf '==> %s\n' "$*"; }
ok()   { printf '    ok: %s\n' "$*"; }
skip() { printf '    skip: %s\n' "$*"; }
need() { printf '    MISSING: %s\n' "$*"; }

# Network-safe download: bounded time, max size, silent progress, fails fast.
net_get() {
  curl -fsSL --connect-timeout 10 --max-time 120 --max-filesize 500000000 -o "$1" "$2" 2>/dev/null
}

###############################################################################
say "Step 0: link this repo"
###############################################################################
if [ -L "$LINK" ] && [ "$(readlink -f "$LINK")" = "$REPO_DIR" ]; then
  ok "already linked"
else
  ln -sfn "$REPO_DIR" "$LINK"; ok "linked $LINK -> $REPO_DIR"
fi

###############################################################################
say "Step 1: configs (edit-in-place symlinks)"
###############################################################################
link() {
  local t="$1" s="$2"; mkdir -p "$(dirname "$t")"
  if [ -e "$t" ] && [ ! -L "$t" ]; then skip "real file present: $t (leave as-is)"; return 0; fi
  ln -sfn "$s" "$t"; ok "link $t"
}
rel="home"
link "$HOME/.claude/CLAUDE.md"            "$LINK/$rel/AGENTS.md"
link "$HOME/.codex/AGENTS.md"             "$LINK/$rel/AGENTS.md"
link "$HOME/.config/opencode/AGENTS.md"   "$LINK/$rel/AGENTS.md"
link "$HOME/.config/nvim"                 "$LINK/$rel/.config/nvim"
link "$HOME/.config/wezterm"              "$LINK/$rel/.config/wezterm"
link "$HOME/.config/herdr"                "$LINK/$rel/.config/herdr"
link "$HOME/.local/bin/sysres"            "$LINK/$rel/.local/bin/sysres"
# pi agent - themes + extensions edit-in-place from repo.
# settings.json + models.json intentionally NOT linked: Pi-managed and hold
# provider API keys; bootstrap only merges aesthetic keys into a live settings.
link "$HOME/.pi/agent/themes"             "$LINK/$rel/.pi/agent/themes"
link "$HOME/.pi/agent/extensions"         "$LINK/$rel/.pi/agent/extensions"
# pi settings.json - merge repo's aesthetic keys into the live file (keep provider/model).
if [ -e "$HOME/.pi/agent/settings.json" ]; then
  mkdir -p "$HOME/.pi/agent"
  if command -v jq >/dev/null 2>&1; then
    jq -s '.[1] * .[0]' "$HOME/.pi/agent/settings.json" "$LINK/$rel/.pi/agent/settings.json" > "$HOME/.pi/agent/settings.json.tmp" \
      && mv "$HOME/.pi/agent/settings.json.tmp" "$HOME/.pi/agent/settings.json" \
      && ok "pi settings.json merged (repo aesthetic keys preserved live provider)" \
      || skip "pi settings merge failed (jq)"
  else
    skip "jq missing - pi settings merge skipped"
  fi
else
  link "$HOME/.pi/agent/settings.json" "$LINK/$rel/.pi/agent/settings.json"
fi
# claude settings.json - MERGED (preserve live hooks/keys)
if [ -e "$HOME/.claude/settings.json" ] && [ ! -L "$HOME/.claude/settings.json" ]; then
  ok "claude settings.json already live (left untouched; see home/ for reference)"
else
  link "$HOME/.claude/settings.json"      "$LINK/$rel/.claude/settings.json"
fi

###############################################################################
say "Step 2: user-space tools (no sudo)"
###############################################################################
# jq - static single binary
if command -v jq >/dev/null 2>&1; then ok "jq $($BIN_DIR/jq --version 2>/dev/null || jq --version)"
else
  say "installing jq (static)"
  if net_get "$BIN_DIR/jq.tmp" "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"; then
    chmod +x "$BIN_DIR/jq.tmp" && mv "$BIN_DIR/jq.tmp" "$BIN_DIR/jq"
    ok "jq $("$BIN_DIR/jq" --version)"
  else skip "jq download failed (network); retry later or install manually"
  fi
fi

# Neovim - official linux-x64 tarball, user-space
if command -v nvim >/dev/null 2>&1; then ok "nvim $(nvim --version | head -1)"
else
  say "installing neovim (official tarball)"
  if net_get "$BIN_DIR/nvim.tar.gz" "https://github.com/neovim/neovim/releases/download/v0.10.4/nvim-linux-x86_64.tar.gz"; then
    tar -xzf "$BIN_DIR/nvim.tar.gz" -C "$BIN_DIR"
    rm -f "$BIN_DIR/nvim.tar.gz"
    ln -sf "$BIN_DIR/nvim-linux-x86_64/bin/nvim" "$BIN_DIR/nvim"
    ok "nvim version 0.10.4 -> $BIN_DIR/nvim"
  else skip "neovim download failed (network); retry later or install manually"
  fi
fi

###############################################################################
say "Step 3: firstmate deps (pinned, checksum-verified)"
###############################################################################
herdr_install() {
  if command -v herdr >/dev/null 2>&1; then ok "herdr $("$BIN_DIR/herdr" --version 2>/dev/null || herdr --version)"; return 0; fi
  if [ -x "$FIRSTMATE_DIR/bin/fm-install-herdr.sh" ]; then
    say "installing herdr via firstmate pinned installer"
    bash "$FIRSTMATE_DIR/bin/fm-install-herdr.sh" "$BIN_DIR" || need "herdr install failed"
    ok "herdr installed"
  else need "herdr installer not found (clone ~/firstmate first)"
  fi
}
herdr_install

treehouse_install() {
  if command -v treehouse >/dev/null 2>&1; then ok "treehouse present"; return 0; fi
  if [ -x "$FIRSTMATE_DIR/bin/fm-install-treehouse.sh" ]; then
    say "installing treehouse via firstmate pinned installer"
    bash "$FIRSTMATE_DIR/bin/fm-install-treehouse.sh" "$BIN_DIR" || need "treehouse install failed"
    ok "treehouse installed"
  else need "treehouse installer not found (clone ~/firstmate first)"
  fi
}
treehouse_install

###############################################################################
say "Step 4: agent CLIs (auto-detect, skip clean when absent)"
###############################################################################
for name in claude codex pi opencode; do
  if command -v "$name" >/dev/null 2>&1; then ok "$name: $("$name" --version 2>/dev/null | head -1 || true)"
  else skip "$name not installed (no official unattended installer wired)"
  fi
done

###############################################################################
say "Step 4a: WSL npm IPv6 fix (Happy Eyeballs workaround)"
###############################################################################
# Node ≥20 defaults autoSelectFamily=true ("Happy Eyeballs"), which tries
# IPv6 first. Under WSL's NAT DNS, AAAA records resolve but IPv6 routes
# are unreachable, so npm hangs on connect and eventually ETIMEDOUT.
# Fix: preload wsl-npm-asf-fix.js (sets autoSelectFamily=false) via a
# wrapper script, and tell pi to use that wrapper via `npmCommand`.
# This block is a no-op on non-WSL systems.
if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
  say "WSL detected — installing npm IPv6 workaround"

  # Install the wrapper script to ~/.local/bin
  WSL_NPM_WRAPPER="$BIN_DIR/wsl-npm-wrapper.sh"
  cp "$REPO_DIR/wsl-npm-wrapper.sh" "$WSL_NPM_WRAPPER"
  chmod +x "$WSL_NPM_WRAPPER"
  ok "wsl-npm-wrapper.sh -> $WSL_NPM_WRAPPER"

  # Verify the preload script is reachable via the repo symlink
  if [ -f "$LINK/wsl-npm-asf-fix.js" ]; then
    ok "wsl-npm-asf-fix.js reachable at $LINK/wsl-npm-asf-fix.js"
  else
    need "wsl-npm-asf-fix.js not found at $LINK/ (wrapper will fail)"
  fi

  # Inject npmCommand into pi's settings.json (only if pi is installed)
  if command -v pi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    PI_SETTINGS="$HOME/.pi/agent/settings.json"
    mkdir -p "$(dirname "$PI_SETTINGS")"
    if [ -f "$PI_SETTINGS" ]; then
      # Only inject if npmCommand is not already set
      if jq -e '.npmCommand' "$PI_SETTINGS" >/dev/null 2>&1; then
        ok "npmCommand already set in pi settings.json (left as-is)"
      else
        jq --arg wrapper "$WSL_NPM_WRAPPER" \
           '. + {"npmCommand": [$wrapper]}' \
           "$PI_SETTINGS" > "$PI_SETTINGS.tmp" \
          && mv "$PI_SETTINGS.tmp" "$PI_SETTINGS" \
          && ok "npmCommand injected into pi settings.json" \
          || need "failed to merge npmCommand into pi settings.json"
      fi
    else
      # No existing settings — create minimal file with npmCommand
      printf '{"npmCommand":["%s"]}\n' "$WSL_NPM_WRAPPER" > "$PI_SETTINGS"
      ok "created pi settings.json with npmCommand"
    fi
  else
    if ! command -v pi >/dev/null 2>&1; then
      skip "pi not installed — npmCommand not injected (will be set on next run)"
    elif ! command -v jq >/dev/null 2>&1; then
      skip "jq not available — npmCommand not injected (install jq and re-run)"
    fi
  fi
else
  skip "not WSL — IPv6 workaround not needed"
fi

###############################################################################
say "Step 4b: pi-retry extensions (auto-install via pi CLI)"
###############################################################################
# @narumitw/pi-retry — watchdog-based stall retry.
#   Detects provider errors (stopReason:"error"), Codex backend errors, and
#   websocket connection limits. Uses a stall watchdog (default ~90s timeout,
#   configurable via --retry-stall-timeout-ms or PI_RETRY_STALL_TIMEOUT_MS).
#   Relies on Pi's built-in retry policy; warns if disabled. No deps.
# @monotykamary/pi-retry — catch-all exponential backoff retry.
#   Retries everything by default (blacklist: bad API key, model not found,
#   unsupported model). Backoff 2s→4s→8s…→60s cap. Built-in slash commands:
#   /retry, /retry status, /retry reset. No deps.
#
# Both are installed as Pi extensions via:  pi install npm:@scope/pi-retry
# Versions are pinned (npm:@scope/pi-retry@<version>) to prevent unreviewed code
# from being auto-installed on subsequent bootstrap runs — extensions execute
# with full system access. Update versions deliberately via Step 6 / pi update.
# Latest pinned versions as of this bootstrap:
#   @narumitw/pi-retry      0.31.0
#   @monotykamary/pi-retry  0.6.9
NARUMITW_PI_RETRY_VER="0.31.0"
MONOTYKAMARY_PI_RETRY_VER="0.6.9"
# The `pi` CLI is expected at /usr/local/bin/pi or $HOME/.local/bin/pi.
if command -v pi >/dev/null 2>&1; then
  PI_CMD="$(command -v pi)"

  # @narumitw/pi-retry
  # Stall watchdog timeout is persisted via the shell helpers block (Step 5)
  # so it applies to all later `pi` sessions, not just this install process.
  if "$PI_CMD" list 2>/dev/null | grep -q "npm:@narumitw/pi-retry@${NARUMITW_PI_RETRY_VER}"; then
    ok "@narumitw/pi-retry already installed ($NARUMITW_PI_RETRY_VER)"
  else
    say "installing @narumitw/pi-retry v${NARUMITW_PI_RETRY_VER} (stall watchdog retry)"
    if "$PI_CMD" install "npm:@narumitw/pi-retry@${NARUMITW_PI_RETRY_VER}" 2>/dev/null; then
      ok "@narumitw/pi-retry installed"
    else
      need "@narumitw/pi-retry install failed (pi CLI or network issue)"
    fi
  fi

  # @monotykamary/pi-retry
  if "$PI_CMD" list 2>/dev/null | grep -q "npm:@monotykamary/pi-retry@${MONOTYKAMARY_PI_RETRY_VER}"; then
    ok "@monotykamary/pi-retry already installed ($MONOTYKAMARY_PI_RETRY_VER)"
  else
    say "installing @monotykamary/pi-retry v${MONOTYKAMARY_PI_RETRY_VER} (catch-all backoff retry)"
    if "$PI_CMD" install "npm:@monotykamary/pi-retry@${MONOTYKAMARY_PI_RETRY_VER}" 2>/dev/null; then
      ok "@monotykamary/pi-retry installed"
    else
      need "@monotykamary/pi-retry install failed (pi CLI or network issue)"
    fi
  fi
else
  skip "pi CLI not found — pi-retry extensions not installed"
  skip "  install manually: pi install npm:@narumitw/pi-retry@${NARUMITW_PI_RETRY_VER}"
  skip "  install manually: pi install npm:@monotykamary/pi-retry@${MONOTYKAMARY_PI_RETRY_VER}"
fi

###############################################################################
say "Step 5: shell helpers (idempotent)"
###############################################################################
SHELLRC="$HOME/.bashrc"
# Decide whether to export FM_BACKEND=herdr (only if herdr installed).
FM_BACKEND_EXPORT=''
if [ -x "$BIN_DIR/herdr" ]; then
  # also confirm the firstmate backend config + config file exist
  if [ -f "$FIRSTMATE_DIR/config/backend" ] && [ -s "$HOME/.config/herdr/config.toml" ]; then
    FM_BACKEND_EXPORT='export FM_BACKEND=herdr  # use herdr backend (tmux default otherwise)'
    ok "herdr present -> will export FM_BACKEND=herdr"
  else
    skip "herdr installed but backend config absent (leaving default tmux)"
  fi
else
  ok "no herdr installed (backend default: tmux)"
fi
# Build the bashrc block; inject FM_BACKEND export only when applicable.
FM_BACKEND_LINE=''
if [ -n "$FM_BACKEND_EXPORT" ]; then
  FM_BACKEND_LINE="$FM_BACKEND_EXPORT"
fi
BLOCK='
# ---- dotfiles-wsl (kunchenguid-style aliases, adapted) ----
# everyday Claude: SAFE (normal permission prompts)
alias cc='"'"'claude'"'"'
# FIRSTMATE-ONLY high-agency launcher: claude --dangerously-skip-permissions
# scoped to the crew home, so everyday `cc` stays guarded.
fm() { cd "$HOME/firstmate" && claude --dangerously-skip-permissions "$@"; }
# FIRSTMATE with the Pi agent: pi --approve (trusts project-local files).
# Scope: --approve only trusts project-local files, NOT full permission bypass.
fm-pi() { cd "$HOME/firstmate" && pi --approve "$@"; }
alias firstmate='"'"'cd ~/firstmate && claude'"'"'
alias fm-peek='"'"'bash ~/.dotfiles-wsl/fm-peek.sh'"'"'
alias fm-watch='"'"'bash ~/.dotfiles-wsl/fm-watch.sh'"'"'
# pull latest dotfiles from GitHub and re-apply
fm-update() { cd ~/.dotfiles-wsl && git pull --ff-only && ./bootstrap.sh; }
# pi-retry: stall watchdog timeout (seconds) for @narumitw/pi-retry.
# Persisted here so it applies to all future pi sessions, not just install.
export PI_RETRY_STALL_TIMEOUT_MS=30000
export PATH="$HOME/.local/bin:$PATH"
'"$FM_BACKEND_LINE"'
# ---- end dotfiles-wsl ----'

if grep -q "# ---- end dotfiles-wsl ----" "$SHELLRC"; then
  # remove any existing blocks, then re-add a single clean one
  awk '/# ---- dotfiles-wsl \(kunchenguid-style aliases, adapted\) ----/{skip=1} !skip{print} /# ---- end dotfiles-wsl ----/{skip=0}' "$SHELLRC" > "$SHELLRC.tmp" \
    && mv "$SHELLRC.tmp" "$SHELLRC"
fi
printf '%s\n' "$BLOCK" >> "$SHELLRC"
if ! grep -q 'HOME/.local/bin' "$SHELLRC"; then
  printf '\n# dotfiles-wsl: gh etc\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$SHELLRC"
fi
ok "aliases + PATH in $SHELLRC (single block)"

###############################################################################
say "Step 6: verify"
###############################################################################
echo "--- tools ---"
for t in git tmux claude jq nvim herdr treehouse node gh; do
  if command -v "$t" >/dev/null 2>&1; then echo "   [ok] $t"; else echo "   [--] $t"; fi
done
echo "--- agents ---"
for t in claude codex pi opencode; do
  if command -v "$t" >/dev/null 2>&1; then echo "   [ok] $t"; else echo "   [--] $t (not installed)"; fi
done
echo "--- pi extensions ---"
if command -v pi >/dev/null 2>&1; then
  for pkg in "npm:@narumitw/pi-retry" "npm:@monotykamary/pi-retry"; do
    if pi list 2>/dev/null | grep -q "$pkg"; then echo "   [ok] $pkg";
    else echo "   [--] $pkg (not installed)"; fi
  done
else
  echo "   [--] pi CLI not found (extensions not installed)"
fi
echo "--- firstmate ---"
if [ -d "$FIRSTMATE_DIR" ]; then echo "   [ok] firstmate @ $(git -C "$FIRSTMATE_DIR" rev-parse --short HEAD 2>/dev/null || echo ?)";
  [ -f "$FIRSTMATE_DIR/config/backend" ] && echo "         backend=$(cat "$FIRSTMATE_DIR/config/backend")" || echo "         backend=tmux (default)"; fi

say "Done. Open a new shell, then: cd ~/firstmate && claude   (or: firstmate)"