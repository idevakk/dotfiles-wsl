# dotfiles-wsl

A WSL/Ubuntu adaptation of [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles),
capturing the same idea: **one repo, one command, and a fresh WSL ends up configured the
same way every time** - but with plain bash instead of Nix.

## Why (not Nix)

kunchenguid's setup uses `nix-darwin` + `home-manager` for macOS reproducibility.
On Windows + WSL2 Ubuntu, that's heavy machinery for little gain - WSL already has most
tools, Homebrew doesn't apply, and Nix adds a whole layer. So this keeps his **logic**
and swaps the engine:

| His (macOS) | This (WSL) |
|---|---|
| `nix-darwin` + `home-manager` apply config | `./bootstrap.sh` applies config |
| `mkOutOfStoreSymlink` edit-in-place | plain `ln -sfn` symlinks, edit-in-place |
| `home/AGENTS.md` -> `~/.claude/CLAUDE.md`, `.codex`, `.opencode` | same symlinks |
| `home/.claude/settings.json` (dark-ansi + statusline) | same settings file |
| `cc`/`co` aliases (high-agency) | `cc` = plain `claude` (opt-in skip-permissions) |
| herdr / Pi / nvim / wezterm | firstmate helpers; skip macOS-only stuff |

## Setup

```sh
git clone https://github.com/<you>/dotfiles-wsl ~/dotfiles-wsl
cd ~/dotfiles-wsl
./bootstrap.sh
```

That's it. Re-run it after editing config to re-apply (idempotent).

## What bootstrap.sh does

1. **Checks prerequisites** (git, tmux, node, claude, gh, jq).
2. **Symlinks this repo to `~/.dotfiles-wsl`** (so symlinks below resolve).
3. **Symlinks config into place** - `~/.claude/settings.json`,
   `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`.
   The real files live in `home/` here; editing them edits your live config.
4. **Adds shell aliases** to `~/.bashrc` (`cc`, `firstmate`, `fm-peek`, `fm-watch`).
5. **Ensures `~/.local/bin` is on PATH** (for `gh`).
6. **Reports the firstmate home** (`~/firstmate`) status.

## Firstmate integration

The firstmate crew is separate and lives in `~/firstmate`. This repo's `bootstrap.sh`
checks it and the `fm-peek` / `fm-watch` helpers watch the fleet from outside.

## Notes

- `home/AGENTS.md` is the global agent policy (shared by Claude, Codex, opencode).
  Edit it to match *your* rules.
- The `cc` alias is deliberately the safe `claude`, not `--dangerously-skip-permissions`.
  Uncomment the high-agency line if you want the author's behavior.
- This is WSL/Ubuntu: no nix-darwin, no homebrew, no macOS paths.