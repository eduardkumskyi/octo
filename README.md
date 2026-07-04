# 🐙 octo

Portable AI-agent workflow toolkit: plan → implement → test → review-until-clean → PR,
with a lessons engine that absorbs every bug it sees, an autonomous studio mode,
and Mission Control progress UI. Harness-neutral core; skills follow the open
Agent Skills format.

## Install (Claude Code)

    /plugin marketplace add eduardkumskyi/claude-octo
    /plugin install octo

Other harnesses: `adapters/install.sh` arrives in Plan 4 (symlinks skills into
`~/.claude/skills` and `~/.agents/skills`; see docs/specs for the compatibility matrix).

## What's inside

- `hooks/` — safety guard, file-scoped auto-format, compaction context restore,
  verification notice (all tested: `bash tests/run.sh`)
- `statusline/` — one-line live status for your terminal statusline
- `terminal/octo-anim.py` — the wave: `🐙 ⠤⢄⣀⡠⠔⠒⠉⠉⠒⠤  build · step 3/7`
**Agents:**

- **architect** — planning, system/API design, and codebase exploration
- **implementer** — writes production code from a plan
- **test-engineer** — authors and runs automated tests
- **reviewer** — parameterized review by lens (bugs, security, performance, simplicity)
- **verifier** — confirms a change works by running the real app

**Skills:**

| Skill | Purpose |
|---|---|
| `/octo:plan` | Explore the codebase and produce an implementation plan with SAFE/RISKY assumptions |
| `/octo:implement` | Supervised plan execution: implement → test → checkpoint, file-disjoint tasks in parallel |
| `/octo:test` | Run only the tests affected by the current diff; full suite with `--all` |
| `/octo:review` | Multi-lens parallel review loop; findings verified and fixed until clean (max 3 iterations) |
| `/octo:pr` | Create a pull request with a generated description; falls back to push + compare URL |
| `/octo:debug` | Systematic root-cause debugging: reproduce, rank hypotheses, falsify with evidence |
| `/octo:retro` | Session post-mortem: mine for corrections, distill into lesson cards |
| `/octo:handoff` | Write `.claude/handoff.md` so any future session can resume from the current state |
| `/octo:skill` | Author a new skill, agent, or hook into the octo repo or a host project's `.claude/` |

build, studio, Mission Control — Plan 3; adapters — Plan 4

## Safety guard: what it does NOT do

`hooks/guard.sh` is regex-based defense-in-depth, **not a sandbox**. It blocks
the obvious: force-push, pushes to protected branches, `--no-verify`,
`git reset --hard`, `rm -rf` on root/cwd/src, destructive SQL via DB CLIs,
direct `dbshell`. It does NOT see through shell variables (`psql -c "$Q"`),
heredocs, or files piped into a DB client. Treat it as a seatbelt, not a cage.
Additional known limits: non-origin/upstream remotes are not matched; `rm -rf ~` is
not blocked; `--no-verify` anywhere in a git command's text blocks (fail-closed);
requires GNU or BSD grep — busybox/toybox grep lacks `\s`/`\b` and silently disables rules.

Per-project extras: `.claude/octo.json` (`protected_branches`) and
`.claude/hooks/guard-extra.sh` (sourced with `$CMD` + `block()` available).
`guard-extra.sh` is executed shell code — only add it in repositories you trust.

## Per-project config

See `docs/specs/2026-07-04-claude-octo-design.md` § "Per-project configuration
surface".
