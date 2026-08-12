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
say "Step 5: shell helpers (idempotent)"
###############################################################################
SHELLRC="$HOME/.bashrc"
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
export PATH="$HOME/.local/bin:$PATH"
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
echo "--- firstmate ---"
if [ -d "$FIRSTMATE_DIR" ]; then echo "   [ok] firstmate @ $(git -C "$FIRSTMATE_DIR" rev-parse --short HEAD 2>/dev/null || echo ?)";
  [ -f "$FIRSTMATE_DIR/config/backend" ] && echo "         backend=$(cat "$FIRSTMATE_DIR/config/backend")" || echo "         backend=tmux (default)"; fi

say "Done. Open a new shell, then: cd ~/firstmate && claude   (or: firstmate)"