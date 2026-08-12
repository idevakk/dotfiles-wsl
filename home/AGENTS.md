# global agent instructions (WSL)

This file is installed (symlinked) as `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
and `~/.config/opencode/AGENTS.md` so every agent shares one policy.
Mirrors kunchenguid/dotfiles' edit-in-place model, adapted for WSL/Ubuntu.

- Never use the em dash "—". Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path.
  Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless
  the direct path exposes a concrete blocker or repeated need that justifies the added machinery.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely
  aligned with how an end user would experience it as possible.
  This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with
  pixel perfection. If something clearly looks off, even if it is not directly related to
  what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test
  flakiness. If you see one, even if it is not caused by what you are working on right now,
  still get it fixed.
- Before using "dynamic workflows", "ultra code" or any harness feature that immediately
  spawns a large swarm of subagents, always explain the tradeoffs and ask the user for
  explicit approval.

## Firstmate (this WSL home)

- The firstmate crew lives in `~/firstmate` (primary harness = Claude Code, backend = tmux).
- Crew tasks appear as windows `fm-<id>` in the tmux session named `firstmate`.
- Supervision is event-driven: a bash watcher parks on the fleet and only wakes the primary
  when something needs you. Routine checks use `bin/fm-peek.sh <id>` and
  `FM_HOME=$PWD bin/fm-send.sh <id> '<text>'` - no need to attach.
- State is restart-proof: killing the session is fine, the next launch reconciles.
- This machine is Windows + WSL2 Ubuntu. Do NOT propose installing Nix/home-manager or
  macOS-only tooling (nix-darwin, homebrew, wezterm-mac paths) here.

## System resources (sysres)

`sysres` is a lightweight, agent-agnostic resource check on PATH (`~/.local/bin/sysres`),
available to this agent via the bash tool. It reads `/proc`/`/sys`, reports
memory / CPU load / disk / open FDs, and emits a `VERDICT: green|amber|red` plus a
machine-checkable exit code (`0` green, `1` amber, `2` red). Run `sysres -h` for
usage, `sysres -j` for JSON, `sysres -q` for one line.

- Run `sysres` BEFORE launching any heavy or parallel work: launching a batch of
  Docker containers or `docker compose up` of many services, running multiple
  builds at once, large test matrices, model training, or several dev servers at once.
- Interpret the verdict: `green` (exit 0) = go ahead. `amber` (exit 1) = proceed
  with caution, prefer running tasks one at a time. `red` (exit 2) = do NOT launch
  heavy work now; wait, sequence, or reduce concurrency first.
- Treat `exit 255` (all values unknown) as "cannot tell" - do not assume the system
  is safe; retry once or proceed cautiously.
- Do NOT run `sysres` for normal trivial commands, or to second-guess every single
  command. It exists for heavy or many-concurrent tasks, not per-command gating.