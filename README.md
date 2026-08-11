# dotfiles-wsl

A WSL/Ubuntu adaptation of [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles),
capturing the same idea: **one repo, one command, and a fresh WSL ends up configured the
same way every time** - but with plain bash instead of Nix. Now also a **one-shot
auto-installer** for the full WSL agent home (jq, Neovim, herdr, treehouse, agent CLIs).

## Why (not Nix)

kunchenguid's setup uses `nix-darwin` + `home-manager` for macOS reproducibility.
On Windows + WSL2 Ubuntu, that's heavy machinery for little gain - WSL already has most
tools, Homebrew doesn't apply, and Nix adds a whole layer. So this keeps his **logic**
and swaps the engine:

| His (macOS) | This (WSL) |
|---|---|
| `nix-darwin` + `home-manager` apply config | `./bootstrap.sh` applies config + installs tools |
| `mkOutOfStoreSymlink` edit-in-place | plain `ln -sfn` symlinks, edit-in-place |
| `home/AGENTS.md` -> `.claude/.codex/.opencode` | same symlinks |
| `home/.claude/settings.json` | kept live (merged / documented) |
| `cc`/`co` aliases (high-agency) | `cc` = plain `claude` (opt-in skip-permissions) |
| herdr / Pi / nvim / wezterm configs | **all included** and auto-wired |

## Setup - one command

```sh
git clone https://github.com/idevakk/dotfiles-wsl ~/dotfiles-wsl
cd ~/dotfiles-wsl
./bootstrap.sh
```

That's it. Re-run it after editing config to re-apply (idempotent).

## What bootstrap.sh installs & configures

| Component | What happens |
|---|---|
| repo link | symlinks this repo to `~/.dotfiles-wsl` |
| configs | symlinks `~/.claude/CLAUDE.md`, `.codex/AGENTS.md`, `.opencode/AGENTS.md`, `~/.config/nvim`, `~/.config/wezterm`, `~/.config/herdr` (edit-in-place) |
| jq | static binary -> `~/.local/bin` |
| Neovim | official linux-x64 tarball -> `~/.local/bin/nvim` |
| herdr | firstmate's **pinned, checksum-verified** installer -> `~/.local/bin/herdr` |
| treehouse | firstmate's pinned installer (task worktrees) |
| agents | auto-detect `claude`, `codex`, `pi`, `opencode`; **skip clean if absent** |
| shell | aliases `cc`/`firstmate`/`fm-peek`/`fm-watch` + `~/.local/bin` on PATH |
| verify | reports every tool/agent/firstmate status |

**User-space only - no sudo required.**

## The configs included

- **`home/AGENTS.md`** - shared agent policy for Claude, Codex, opencode (edit-in-place).
- **`home/.config/nvim/**`** - Neovim with lazy.nvim + rose-pine moon (Neogit, git, nav, ui).
- **`home/.config/wezterm/wezterm.lua`** - rose-pine moon terminal config (GUI renders on
  Windows-side WezTerm / WSLg; also usable in the herdr TUI).
- **`home/.config/herdr/config.toml`** - herdr backend keybindings.
- **`home/.pi/agent/**`** - Pi alternate agent: rose-pine-moon theme, `calm` extension,
  terminal-status-title, models/settings pins.

## Agent CLIs

`bootstrap.sh` **auto-detects** `claude`, `codex`, `pi`, `opencode` and skips any that
aren't installed. Install them on your own (they need their own auth):

```sh
# Claude Code
curl -fsSL https://claude.ai/install.sh | bash   # or your usual installer
# Codex
npm install -g @openai/codex
# Pi
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
# opencode
npm install -g opencode-ai
```

After installing one, re-run `./bootstrap.sh` - it will now see it and link its config.

## Firstmate integration

The firstmate crew lives in `~/firstmate`. `bootstrap.sh` checks it and the
`fm-peek` / `fm-watch` helpers watch the fleet from outside. Launch the crew with:

```sh
cd ~/firstmate && claude   # or:  firstmate
```

## Notes

- `home/AGENTS.md` is the global agent policy. Edit it to match *your* rules.
- The `cc` alias is deliberately the safe `claude`, not `--dangerously-skip-permissions`.
- This is WSL/Ubuntu: no nix-darwin, no homebrew, no macOS paths.