# HANDOFF — FirstMate + dotfiles-wsl on WSL

This file is the complete context for a new Claude Code session working in this repo.
Read this first. It captures everything built in the original session (Aug 2026),
so you don't have to re-discover any of it.

---

## 1. What this repo is

**`dotfiles-wsl`** — a plain-bash (no Nix) reproduction of [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles),
whose author is the same `kunchenguid` who writes **FirstMate** (an "agent distro" that turns a
primary agent harness like Claude Code into a supervisor for a parallel crew of agents).

The repo is a **one-shot WSL agent-home installer**:

```
git clone https://github.com/idevakk/dotfiles-wsl   # public, no auth needed
cd dotfiles-wsl && ./bootstrap.sh
```

`bootstrap.sh` (idempotent, user-space, no sudo) will:
1. Symlink the repo to `~/.dotfiles-wsl`.
2. Symlink configs into place (edit-in-place): `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
   `~/.config/opencode/AGENTS.md`, `~/.config/nvim`, `~/.config/wezterm`, `~/.config/herdr`.
3. Install user-space tools: **jq** (static), **neovim** (official tarball), and FirstMate's
   **pinned, checksum-verified** installers for **herdr** and **treehouse**.
4. Auto-detect agent CLIs (`claude`, `codex`, `pi`, `opencode`) and **skip clean** if absent.
5. Add shell helpers to `~/.bashrc`: `cc` (safe claude), `fm` (FirstMate-only high-agency),
   `fm-update` (pull + reapply), `fm-peek`, `fm-watch`, plus PATH export.

The `home/` directory holds the real config files (shared agent policy, settings, nvim,
wezterm, herdr, Pi). Editing them edits your live config; re-run `./bootstrap.sh` to re-apply.

## 2. Where things live (live WSL state, verified)

- **`~/firstmate`** — the FirstMate "agent distro" clone (`kunchenguid/firstmate` @ `e8c7645`).
  Its `.claude/settings.json` registers the **Stop hook** protocol (see §4).
- **`~/firstmate/config/backend`** — contains `tmux` (the runtime backend).
- **`~/dotfiles-wsl`** — a clone of this repo in WSL home (the live source of truth).
  `~/.dotfiles-wsl` is a **symlink** → `~/dotfiles-wsl`.
- **`~/.local/bin`** — user-space tools: `gh`, `jq`, `nvim`, `herdr`, `treehouse`.
- **`~/.config/{nvim,wezterm,herdr}`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
  `~/.config/opencode/AGENTS.md`** — symlinked into `~/dotfiles-wsl/home/...`.
- **`~/.claude/settings.json`** — the user's LIVE file (has a `gh-axi` SessionStart hook +
  `skipDangerousModePermissionPrompt`); it is NOT overwritten by bootstrap (merge/left intact).

## 3. The WSL architecture / how the pieces fit

```
Windows (Windows Terminal)
  -> WSL2 Ubuntu (user: atulk)
     -> claude  (primary harness / "the first mate")  running inside ~/firstmate
        -> bin/  (fm-peek, fm-send, fm-watch, fm-afk, ...)  the "toolbelt"
        -> Stop hook  -> auto-arms the watcher at every turn end
        -> watcher (bin/fm-watch.sh)  -> wakes the first mate only when something needs you
        -> tmux session "firstmate"
           -> window fm-<id> = crewmate agent in its own treehouse git worktree
     -> GitHub (gh): clone -> worktrees -> push branches -> PR -> merge
```

- The crew is **GitHub-centric**: FirstMate clones a repo under `~/firstmate/projects/`,
  spawns parallel crewmates (each a tmux window + isolated worktree under `~/.treehouse/`),
  and delivers **PRs** you review and merge.
- **State is restart-proof**: kill the session anytime; the next launch reconciles.
- The watcher is **tokenless** (owned by the Stop hook, not the model).

## 4. The Stop-hook protocol (Claude <-> FirstMate)

In `~/firstmate/.claude/settings.json`:
- **Stop hook** runs `bin/fm-turnend-guard.sh --claude` (bounded fail-open backstop) and
  `bin/fm-claude-stop-autoarm.sh` (`asyncRewake: true`, 8h timeout). On every Stop it
  auto-arms the watcher; exits 2 (asyncRewake) only when there's an actionable wake.
- The watcher `bin/fm-watch.sh` parks and emits one reason line (`signal:` / `stale:` /
  `check:` / `heartbeat:`) for actionable wakes. You never run `fm-watch-arm.sh` manually
  on a normal wake — the next turn-end re-arms automatically.

## 5. Agent CLIs & the two entry points

- **`cc`** = safe everyday Claude (`claude`) — normal permission prompts.
- **`fm`** = FirstMate-only high-agency launcher:
  `fm() { cd "$HOME/firstmate" && claude --dangerously-skip-permissions "$@"; }`
  Deliberately scoped: only the crew home gets the flag; everyday `cc` stays guarded.
  **Caveat**: `--dangerously-skip-permissions` is a session flag, not directory-scoped —
  `fm` is a convention, not a hard wall.
- **`fm-update`** = `cd ~/.dotfiles-wsl && git pull --ff-only && ./bootstrap.sh`.
- Install agents manually (they need their own auth): claude via `curl -fsSL https://claude.ai/install.sh | bash` (or your installer); codex `npm i -g @openai/codex`; pi `npm i -g --ignore-scripts @earendil-works/pi-coding-agent`; opencode `npm i -g opencode-ai`. Re-run bootstrap after to link them.

## 6. Terminal backends

- **tmux** — reference default, **configured** (`config/backend` = `tmux`). Crew = windows `fm-<id>` in session `firstmate`.
- **herdr** 0.7.4 — experimental agent-native backend; **installed** (protocol 16) and config
  present (`~/.config/herdr/config.toml`, from the original dotfiles). Switch with
  `echo herdr > ~/firstmate/config/backend` or `FM_BACKEND=herdr`. Note: herdr is
  dual-licensed AGPL/commercial; verify before production. FirstMate's own docs warn that
  the opencode submit path on herdr is a known gap.
- zellij / cmux / orca — experimental, opt-in.

## 7. What's verified (proof it works)

- FirstMate crew ran a real demo on **`github.com/idevakk/firstmate-demo`** (private):
  2 crewmates worked in parallel worktrees, created **2 PRs, both merged** (divide +
  subtract functions). `projects/firstmate-demo` + `~/.treehouse/` still exist.
- Watcher arm proven live: `watcher: started pid=... (beacon fresh)`, clean lock release,
  `fm-turnend-guard --claude` exit=0.
- `bootstrap.sh` runs idempotently (jq, nvim, herdr, treehouse all `[ok]`, no re-download).
- The `fm()` / `cc` / `fm-update` functions register in an interactive WSL shell.
- dotfiles-wsl repo is **public**: `github.com/idevakk/dotfiles-wsl`, branch `master`.

## 8. Design decisions (do NOT silently revert)

- **No Nix / no homebrew** — plain bash only. This is WSL/Ubuntu; Nix is overkill.
- **`cc` stays safe**; only `fm` carries `--dangerously-skip-permissions` (scoped high-agency).
- **User-space installs only** — everything to `~/.local/bin`, no sudo. jq/nvim use bounded
  `curl` (`net_get`) so re-runs never hang; herdr/treehouse use FirstMate's pinned,
  SHA-256-verified installers (never floating `latest`).
- **`~/.claude/settings.json` is left untouched** (user's live file with `gh-axi` hook).
- **Agent CLIs are auto-detected, never force-installed** — each needs its own interactive auth.

## 9. Repo layout

```
bootstrap.sh        # the one-shot installer (main entry)
fm-peek.sh          # watch the fleet from outside tmux
fm-watch.sh         # continuous fleet watch
README.md           # full docs + setup
HANDOFF.md          # this file
home/
  AGENTS.md                     # shared agent policy (Claude/Codex/opencode)
  .claude/settings.json         # reference claude settings (theme + statusline)
  .config/nvim/                 # lazy.nvim + rose-pine (from original dotfiles)
  .config/wezterm/wezterm.lua   # rose-pine moon terminal config
  .config/herdr/config.toml     # herdr keybindings
  .pi/agent/                    # Pi alternate agent (theme, calm ext, models, settings)
```

## 10. Open items / next steps (candidate work for the new session)

1. **Update flow polish**: `fm-update` is live; confirm README documents it.
2. **Codex**: not installed on the machine; decide whether to add an installer.
3. **Docker / WSLg / Claude-Desktop-Linux** were discussed as questions (possible but not the
   right primary path) — no action taken; don't revisit unless asked.
4. **Demo artifacts** in `~/firstmate/projects/firstmate-demo` and `~/.treehouse/` could be
   cleaned up on request.
5. Consider adding a `herdr`-backend smoke check if you switch away from tmux.

## 11. How a NEW conversation should start

```
1. cd ~/dotfiles-wsl   (WSL)  # or wherever this repo is cloned
2. Read HANDOFF.md (this file) and README.md
3. Check live state: readlink ~/.dotfiles-wsl, git -C ~/dotfiles-wsl log -1,
   ls ~/.local/bin, tmux has-session -t firstmate
4. If you need FirstMate context, the authoritative source is ~/firstmate
   (docs/, bin/, .claude/settings.json).
```

Environment: **Windows 11 + WSL2 Ubuntu (user `atulk`), git 2.45.1, gh 2.97.0 (authed as
`idevakk` id 219866223), Claude Code 2.1.x, tmux 3.6, node, python3, jq, nvim 0.10.4,
herdr 0.7.4, treehouse 2.0.1, pi 0.84.1, opencode 1.18.15.**
