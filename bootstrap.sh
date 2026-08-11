#!/usr/bin/env bash
# dotfiles-wsl - reproduce kunchenguid/dotfiles bootstrap for WSL/Ubuntu.
# One command takes a fresh WSL from nothing to a configured agent home.
# Run this once per machine; re-run to re-apply (idempotent).
# The "home/" files are the real files; this symlinks them into place so
# editing home/AGENTS.md edits your live agent policy (edit-in-place model).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="$REPO_DIR/home"
DOTFILES_LINK="$HOME/.dotfiles-wsl"

echo "==> Step 0: prerequisites"
for t in git tmux node claude gh jq; do
  if command -v "$t" >/dev/null 2>&1; then echo "    ok: $t"; else echo "    MISSING: $t"; fi
done

echo "==> Step 1: symlink this repo to ~/.dotfiles-wsl"
if [ -L "$DOTFILES_LINK" ] && [ "$(readlink -f "$DOTFILES_LINK")" = "$REPO_DIR" ]; then
  echo "    already linked"
else
  ln -sfn "$REPO_DIR" "$DOTFILES_LINK"
  echo "    linked $DOTFILES_LINK -> $REPO_DIR"
fi

echo "==> Step 2: symlink config files (edit-in-place)"
# Mirror of home.nix's mkOutOfStoreSymlink. Each path is replaced by a symlink
# pointing at the real file in this repo, so the two never drift.
link() {
  local target="$1" src="$2"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "    SKIP (real file present, not a symlink): $target"
    echo "          move it aside or delete it, then re-run to link"
    return 0
  fi
  ln -sfn "$src" "$target"
  echo "    link $target -> $src"
}

merge_json() {
  # Merge a repo-provided JSON file (src) INTO an existing live file (target),
  # preserving the live file's keys. Uses python3 (present on WSL).
  local target="$1" src="$2"
  if [ -e "$target" ] && [ ! -L "$target" ] && command -v python3 >/dev/null 2>&1; then
    cp "$target" "$target.dotfiles-wsl.bak"
    python3 - "$target" "$src" <<'PY'
import json, sys
target, src = sys.argv[1], sys.argv[2]
live = json.load(open(target)); repo = json.load(open(src))
# live keys win; repo provides anything missing. Hooks: append repo hooks for
# events not already present, keeping live hooks authoritative.
out = dict(repo); out.update(live)
lh = live.get("hooks", {}); rh = repo.get("hooks", {})
merged_hooks = dict(rh)
for evt, entries in lh.items():
    # Live entries for this event win; repo provides the event if absent.
    merged_hooks[evt] = entries
out["hooks"] = merged_hooks
json.dump(out, open(target, "w"), indent=2)
print("    merged repo settings INTO live %s (backup: %s)" % (target, target + ".dotfiles-wsl.bak"))
PY
    return 0
  fi
  # No live file, or no python3: fall back to plain symlink (link()).
  link "$target" "$src"
}

# settings.json: merge so live hooks/keys survive; AGENTS files: symlink.
merge_json "$HOME/.claude/settings.json" "$DOTFILES_LINK/home/.claude/settings.json"
link "$HOME/.claude/CLAUDE.md"      "$DOTFILES_LINK/home/AGENTS.md"
link "$HOME/.codex/AGENTS.md"       "$DOTFILES_LINK/home/AGENTS.md"
link "$HOME/.config/opencode/AGENTS.md" "$DOTFILES_LINK/home/AGENTS.md"

echo "==> Step 2b: Pi config (opt-in alternate agent)"
# Mirror home.nix: link only authored Pi files/dirs; credentials & runtime state stay local.
PI_LINK="$DOTFILES_LINK/home/.pi/agent"
if command -v pi >/dev/null 2>&1; then
  link "$HOME/.pi/agent/themes"          "$PI_LINK/themes"
  link "$HOME/.pi/agent/extensions"      "$PI_LINK/extensions"
  link "$HOME/.pi/agent/models.json"     "$PI_LINK/models.json"
  link "$HOME/.pi/agent/settings.json"   "$PI_LINK/settings.json"
  echo "    pi detected: linked theme/extensions/models/settings"
else
  echo "    SKIP: pi not installed. (npm i -g @earendil-works/pi-coding-agent to use it)"
fi

echo "==> Step 3: shell helpers (idempotent, appended only)"
SHELLRC="$HOME/.bashrc"
cat >> "$SHELLRC" <<'EOS'

# ---- dotfiles-wsl (kunchenguid-style aliases, adapted) ----
alias cc='claude'
# high-agency, opt-in: uncomment to use like the author's `cc`
# alias cc='claude --dangerously-skip-permissions'
alias firstmate='cd ~/firstmate && claude'
alias fm-peek='bash ~/dotfiles-wsl/fm-peek.sh'
alias fm-watch='bash ~/dotfiles-wsl/fm-watch.sh'
# ---- end dotfiles-wsl ----
EOS
echo "    appended aliases to $SHELLRC"

echo "==> Step 4: ensure gh on PATH for non-login shells"
mkdir -p "$HOME/.local/bin"
grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null || \
  printf '\n# dotfiles-wsl: gh etc\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$SHELLRC"
echo "    ensured ~/.local/bin on PATH"

echo "==> Step 5: firstmate home present?"
if [ -d "$HOME/firstmate" ]; then
  echo "    found ~/firstmate (rev $(git -C "$HOME/firstmate" rev-parse --short HEAD 2>/dev/null || echo '?'))"
  [ -f "$HOME/firstmate/config/backend" ] && echo "    backend: $(cat "$HOME/firstmate/config/backend")" || echo "    backend: (unset - defaults to tmux)"
else
  echo "    NOT FOUND - clone it:  git clone https://github.com/kunchenguid/firstmate ~/firstmate"
fi

echo "==> Done. Open a new shell, then:  cd ~/firstmate && claude   (or:  firstmate)"
