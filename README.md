# octo — v0.11.0

Portable AI-agent workflow toolkit for Claude Code. Describe what you want — octo picks the
gear automatically. Small fix → implement + verify in minutes; feature → full build; subsystem
→ spec, plan, then build. Fifteen skills, five agents, a lessons engine, a project brain, and
a queue for overnight batch runs.

## Install (Claude Code)

    /plugin marketplace add eduardkumskyi/octo
    /plugin install octo

Fully working after those two commands — no settings, no scaffolding, no per-project
configuration required.

## Usage

    /octo:go fix the login redirect bug

That's it. octo classifies the task (S / M / L), announces the gear, and routes to the
right workflow. Override with `-s`, `-m`, or `-l` if you disagree.

## What's inside

`hooks/` — safety guard, file-scoped auto-format, compaction context restore, verification
notice. All hooks are tested: `bash tests/run.sh`.

**Five agents:**

- **architect** — planning, system/API design, and codebase exploration
- **implementer** — writes production code from a plan
- **test-engineer** — authors and runs automated tests
- **reviewer** — parameterized review by lens (bugs, security, performance, simplicity)
- **verifier** — confirms a change works by running the real app

**Fifteen skills:**

| Skill | What it does |
|---|---|
| `/octo:go` | The front door: describe what you want in a sentence — octo sizes the ceremony automatically; announces the chosen gear; override with -s/-m/-l |
| `/octo:spec` | Turn an idea into a reviewed design doc before any planning: a one-question-at-a-time interview, then a spec covering architecture, data flow, error handling, and testing, self-reviewed for placeholders and contradictions; feeds `/octo:plan` |
| `/octo:plan` | Explore the codebase and produce an implementation plan with numbered, independently verifiable tasks; surfaces every assumption (SAFE/RISKY); RISKY + hard-to-reverse decisions come back as questions before the plan is final |
| `/octo:implement` | Supervised execution of a plan task-by-task: implementer writes code, test-engineer adds tests, targeted tests run, user checkpoint between batches; file-disjoint tasks run in parallel; ends with verifier try-it proof |
| `/octo:build` | Autonomous task mode: plan gate → implement + test in parallel where file-disjoint → targeted tests until green (max 5 cycles) → review until clean (max 3 iterations) → full-suite gate per project weight → try-it proof → offer PR. One command, no mid-run questions after the gate |
| `/octo:studio` | Client mode: one contract sign-off, then agents run like a studio until delivery — consilium panels decide instead of the user, milestones are atomic and verified, all state lives on disk, any session can resume. Zero questions between sign-off and delivery |
| `/octo:queue` | Collect task descriptions all day, then run them unattended: each item becomes a studio mission in its own git worktree, ending in a branch + delivery digest; come back to finished work |
| `/octo:test` | Run only the tests affected by the current diff, printing which tests were selected and why; full suite with `--all`; reads test command and subset syntax from CLAUDE.md |
| `/octo:review` | Four reviewer lenses fan out over the diff in parallel, findings are adversarially verified, confirmed ones fixed, loop repeats until clean (max 3 iterations); confirmed findings become lesson cards |
| `/octo:pr` | Detect base branch, verify not protected, run lint/pre-commit if configured, push, open PR with a generated description that always carries an Assumptions section; falls back to push + compare URL without `gh` |
| `/octo:debug` | Systematic root-cause: reproduce first (ideally as a failing test), rank hypotheses, investigate independent ones in parallel, falsify with evidence, fix the cause not the symptom, keep the repro as a regression test, record a lesson |
| `/octo:retro` | Session post-mortem: mine corrections, confirmed review findings, and debug root causes; distill into lesson cards; merge duplicates and prune stale ones |
| `/octo:handoff` | Write `.claude/handoff.md` capturing current goal, done/remaining tasks, key decisions and assumptions, gotchas, and next step so any future session can resume; the context-restore hook re-injects its head after compaction |
| `/octo:skill` | Author a new skill, agent, or hook — into the octo plugin repo or a host project's `.claude/`; knows current frontmatter formats, hook events, and plugin layout; scaffolds, dry-runs, and commits |
| `/octo:audit` | Pre-merge audit: exhaustive, skeptical, read-only review against a base chosen from a question card, across companion repos confirmed by active-work detection; severity-graded findings with concrete failure modes, cross-repo compatibility, must-fix vs safe-to-defer; optional fix selection after the report |

**`/octo:audit`** resolves the base via explicit arg → `audit base:` in CLAUDE.md → question
card listing origin branches. Companion repos with active work (ahead of base, not on default
branch) are detected from sibling directories and confirmed in a single multiSelect before the
audit runs. After the report, a final question card lets you select findings to fix — nothing
is modified unless you choose to, and pushes are never automatic.

## The `/octo:queue` — overnight batch runner

Add tasks during the day, run them unattended while you sleep:

    /octo:queue add migrate the user settings page to the new design system
    /octo:queue add add rate limiting to the public API
    /octo:queue run

Each item runs as a full `/octo:studio` mission in its own isolated git worktree — separate
branch, separate state, separate delivery digest. Come back to a table of results: status,
branch, and a try-it command per item.

## Project brain

`/octo:build`, `/octo:debug`, and `/octo:retro` maintain `.claude/octo/brain.md` — a
self-updating project map (architecture, where things live, conventions, danger zones, key
flows). Architect, implementer, and reviewer agents load it before every task. The brain stays
useful: capped at ~150 lines, merged when near-duplicate, pruned when stale.

## Reader-first output + try-it proofs

Every delivery is two things:

1. **Short in chat** — one-sentence outcome + a table or checklist. Only what changes your
   next action.
2. **Full detail in a file** — complete reports, evidence, logs written to
   `.claude/octo/reports/YYYY-MM-DD-<skill>-<slug>.md`; path shared in chat.

Every result from build, studio, implement, and go ends with a **Try it** block: the exact
command from verifier evidence plus the observed output. No delivery without proof.

## Watching progress

octo fans out agents aggressively — a build/review turn may run many subagents at once; that's the speed trade the plugin makes by design.

Every skill registers steps in Claude Code's native task list — progress is visible
in-session with zero setup. The native task checklist is the sole progress surface.

Machine tap: `.claude/octo/run/state.json` and `events.jsonl` are written continuously
for build and studio runs if you want to build your own view.

Desktop notifications on milestone verified, blocked, and delivery events fire automatically
via `scripts/notify.sh` (macOS `osascript`, Linux `notify-send`) — no configuration needed.

## The lessons engine

Every confirmed review finding, debug root cause, and user correction becomes a lesson card
in `.claude/octo/lessons/`. Each card captures the anti-pattern, severity, a `file:line`
example, and how to catch it next time. Future runs pass relevant cards to agents before they
start.

Cards are capped (50 per project, 20 global), merged when near-duplicate, and pruned when
outgrown — the store stays useful, not noisy. `/octo:retro` distills a session into cards on
demand; `/octo:debug` and `/octo:review` write cards automatically on exit.

## Safety guard

`hooks/guard.sh` is regex-based defense-in-depth, **not a sandbox**. It blocks
the obvious: force-push, pushes to protected branches, `--no-verify`,
`git reset --hard`, `rm -rf` on root/cwd/src, destructive SQL via DB CLIs,
direct `dbshell`. It does NOT see through shell variables (`psql -c "$Q"`),
heredocs, or files piped into a DB client. Treat it as a seatbelt, not a cage.

**Known limits:** non-origin/upstream remotes are not matched; `rm -rf ~` is not
blocked; `--no-verify` anywhere in a git command's text blocks (fail-closed);
requires GNU or BSD grep — busybox/toybox grep lacks `\s`/`\b` and silently disables rules.

Per-project extras: `.claude/octo.json` (`protected_branches`) and
`.claude/hooks/guard-extra.sh` (sourced with `$CMD` + `block()` available).
`guard-extra.sh` is executed shell code — only add it in repositories you trust.

## Other harnesses

`adapters/install.sh` symlinks skills into `~/.claude/skills` and `~/.agents/skills`,
and agents into `~/.claude/agents`. This lets octo skills work with other Claude Code
installations and any harness that reads those directories:

```bash
./adapters/install.sh                 # install
./adapters/install.sh --uninstall     # undo
```

**OpenCode:** `adapters/opencode/octo-guard.js` is a plugin shim that wires the same
`hooks/guard.sh` into OpenCode's `tool.execute.before` event. Always symlink — do not copy
(Node resolves `__dirname` to the copy's directory, breaking the guard path). Set `OCTO_GUARD`
to the absolute path of `hooks/guard.sh` if you must use a copy. Full install instructions:
`adapters/opencode/README.md`.

## Running multiple sessions

Run state is per-project (`.claude/octo/run/` inside each project root), so parallel
sessions in **different projects** never collide. Only **one** active build or studio run per
project is supported: a second run overwrites the first's state. The `/octo:build` Step-1
guard detects a recent `state.json` (under 15 minutes old) and surfaces it as a RISKY item
before overwriting.

---

Design notes and per-project configuration: `docs/DESIGN.md`.
