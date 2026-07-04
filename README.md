# 🐙 octo

Portable AI-agent workflow toolkit: plan → implement → test → review-until-clean → PR,
with a lessons engine that absorbs every bug it sees, an autonomous studio mode,
and terminal-first progress UI. Harness-neutral core; skills follow the open
Agent Skills format.

## Install (Claude Code)

    /plugin marketplace add eduardkumskyi/octo
    /plugin install octo

## Other harnesses

`./adapters/install.sh` symlinks skills into `~/.claude/skills` and `~/.agents/skills`,
and agents into `~/.claude/agents`. This enables octo skills to work natively across
OpenCode, Codex CLI, Cursor, Gemini CLI, and Goose:

```bash
./adapters/install.sh                 # install
./adapters/install.sh --uninstall     # undo
```

For OpenCode hook wiring: see `adapters/opencode/README.md` (symlink-only guidance;
`OCTO_GUARD` environment variable overrides the guard path). **Caveat:** hook wiring
and subagent formats are per-tool; skills and scripts are the portable core.

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
| `/octo:build` | Autonomous task mode: plan with an up-front assumption gate, implement with tests in parallel where file-disjoint, run targeted tests until green (max 5 cycles), review until clean (max 3 iterations), full-suite gate per project weight, then offer a PR. One command, no mid-run questions after the gate. |
| `/octo:studio` | Client mode: one contract sign-off, then the agents run like a studio until delivery - consilium panels decide instead of the user, milestones are atomic and verified, all state lives on disk, and any session can resume the run. Zero questions between sign-off and delivery. |
| `/octo:test` | Run only the tests affected by the current diff; full suite with `--all` |
| `/octo:review` | Multi-lens parallel review loop; findings verified and fixed until clean (max 3 iterations) |
| `/octo:pr` | Create a pull request with a generated description; falls back to push + compare URL |
| `/octo:debug` | Systematic root-cause debugging: reproduce, rank hypotheses, falsify with evidence |
| `/octo:retro` | Session post-mortem: mine for corrections, distill into lesson cards |
| `/octo:handoff` | Write `.claude/handoff.md` so any future session can resume from the current state |
| `/octo:skill` | Author a new skill, agent, or hook into the octo repo or a host project's `.claude/` |

## Watching progress

The statusline is the passive default — add one snippet to your Claude Code user settings:

```json
"statusLine": {"type": "command", "command": "bash <path-to-octo>/statusline/octo-statusline.sh", "refreshInterval": 3}
```

For an animated live view, run `python3 <path-to-octo>/terminal/octo-anim.py` in a second
terminal while a build or studio run is active.

`.claude/octo/run/state.json` and `events.jsonl` are the machine-readable tap if you want to
build your own view.

### Running multiple sessions

Run state is per-project (`.claude/octo/run/` inside each project root), so parallel sessions
in **different projects** never collide. Only **one** active build or studio run per project is
supported: a second run in the same project overwrites the first's state. The `/octo:build`
Step-1 guard detects a recent `state.json` (under 15 minutes old) and surfaces it as a RISKY
item before overwriting.

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

See `docs/DESIGN.md` § "Per-project configuration
surface".
