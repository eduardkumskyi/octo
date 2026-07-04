# 🐙 octo

Portable AI-agent workflow toolkit: plan → implement → test → review-until-clean → PR,
with a lessons engine that absorbs every bug it sees, an autonomous studio mode,
and Mission Control progress UI. Harness-neutral core; skills follow the open
Agent Skills format.

## Install (Claude Code)

    /plugin marketplace add eduardkumskyi/claude-octo
    /plugin install octo

Other harnesses: `adapters/install.sh` (symlinks skills into `~/.claude/skills`
and `~/.agents/skills`; see docs/specs for the compatibility matrix).

## What's inside

- `hooks/` — safety guard, file-scoped auto-format, compaction context restore,
  verification notice (all tested: `bash tests/run.sh`)
- `statusline/` — one-line live status for your terminal statusline
- `terminal/octo-anim.py` — the wave: `🐙 ⠤⢄⣀⡠⠔⠒⠉⠉⠒⠤  build · step 3/7`
- skills/agents/dashboard — arriving in Plans 2–4

## Safety guard: what it does NOT do

`hooks/guard.sh` is regex-based defense-in-depth, **not a sandbox**. It blocks
the obvious: force-push, pushes to protected branches, `--no-verify`,
`git reset --hard`, `rm -rf` on root/cwd/src, destructive SQL via DB CLIs,
direct `dbshell`. It does NOT see through shell variables (`psql -c "$Q"`),
heredocs, or files piped into a DB client. Treat it as a seatbelt, not a cage.

Per-project extras: `.claude/octo.json` (`protected_branches`) and
`.claude/hooks/guard-extra.sh` (sourced with `$CMD` + `block()` available).

## Per-project config

See `docs/specs/2026-07-04-claude-octo-design.md` § "Per-project configuration
surface".
