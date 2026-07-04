# claude-octo — Personal Claude Code Plugin (Design)

Date: 2026-07-04
Status: draft for review

## Goal

A portable, self-contained Claude Code plugin that carries Eduard's complete
development workflow — plan → implement → test → review → PR — into any project.
It replaces the deprecated per-project setup in `vwd-backend/.claude/` and is
designed to eliminate five measured time sinks:

1. **Review roulette** — one review pass never finds all bugs; review must be
   multi-lens, parallel, and loop until clean.
2. **Test overkill** — heavy projects re-run everything; tests must be selected
   from the diff, full suite only as a final gate.
3. **Lazy parallelism** — work that could fan out runs serially; parallel
   dispatch is the default whenever tasks are independent.
4. **Context decay** — sessions partially lose context after compaction;
   continuity must be wired into hooks, not left to luck.
5. **Silent assumptions** — critical decisions get made without the user
   knowing; every plan/PR surfaces assumptions, and ambiguous + hard-to-reverse
   decisions come back as questions.
6. **Progress blindness** — long tasks give no sense of where they are or how
   much is left; every skill must expose a live step counter and current
   activity, so "how far along is it?" is always answerable at a glance.

## Contract (refined prompt)

- New git repo at `~/PycharmProjects/claude-octo/`, structured as an
  installable plugin with its own marketplace file
  (`/plugin marketplace add <repo>` works from GitHub or local path).
- **Self-contained**: the full dev cycle is covered; superpowers/epsilon become
  optional.
- **Stack-agnostic**: the plugin carries universal engineering discipline;
  every agent reads the host project's `CLAUDE.md` for stack rules before
  acting. No Django/vwd specifics in the plugin.
- **Tri-mode**: per task the user chooses supervised mode (`/octo:implement`
  and the other individual skills), `/octo:build` (autonomous task, hours), or
  `/octo:studio` (autonomous mission, days — one sign-off, agents decide via
  consilium).
- Separately: slim `vwd-backend/.claude/` to only project-specific pieces and
  clean permission cruft (migration section below).

## Repo layout

```
claude-octo/
  .claude-plugin/
    plugin.json            # name "octo", version, author
    marketplace.json       # lists this repo as its own marketplace ("./")
  agents/
    architect.md
    implementer.md
    test-engineer.md
    reviewer.md
    verifier.md
  skills/
    plan/SKILL.md
    implement/SKILL.md
    build/SKILL.md
    test/SKILL.md
    review/SKILL.md
    debug/SKILL.md
    pr/SKILL.md
    handoff/SKILL.md
    retro/SKILL.md
    skill/SKILL.md
    studio/SKILL.md
  statusline/
    octo-statusline.sh     # optional: renders .claude/octo/status.json in the terminal statusline
  hooks/
    hooks.json             # plugin hook wiring via ${CLAUDE_PLUGIN_ROOT}
    guard.sh               # PreToolUse safety guard
    auto-format.sh         # PostToolUse formatter
    context-restore.sh     # SessionStart(compact|resume) context re-injection
    verify-done.sh         # Stop-time "did you actually verify?" notice
  docs/specs/              # this document
  README.md                # install + usage + per-project config reference
```

## Agents (9 → 5)

All agents open with the same preamble: *"Before doing anything, read the
project's CLAUDE.md (and any files it references) for stack rules, commands,
and conventions. Project instructions override your defaults."*

**CLAUDE.md-absent fallback (never silent):** if CLAUDE.md is missing or lacks
a needed section (test command, branch config), the agent/skill states this
explicitly in its output, detects what it can from the repo (lockfiles,
Makefile, CI config), and proceeds with detected defaults; `/octo:plan` and
`/octo:build` additionally offer to scaffold a minimal CLAUDE.md first. The
failure mode to prevent is the plugin *appearing* to work while applying wrong
conventions.

Specializations
that were separate agents (API design, DB tuning, security) become **review
lenses and planning checklists**, not standing agents — fewer agents means less
context bloat and makes parallel lens fan-out affordable.

| Agent | Model | Tools | Role |
|---|---|---|---|
| `architect` | inherit | read-only + Agent | Planning, system/API design, codebase exploration ("read-only" = no Write/Edit/Bash-mutations; Agent dispatch for parallel exploration is allowed). Every plan ends with `## Assumptions` and `## Open Questions`. Absorbs software-architect + api-designer. Also serves as the consilium judge in studio mode. |
| `implementer` | inherit | all | Production code. Discipline: simplicity over cleverness, focused diffs, follow existing patterns, no drive-by refactors. Never writes tests (role separation kept from old setup). |
| `test-engineer` | inherit | all | Writes/repairs tests following project conventions discovered from CLAUDE.md + existing tests. Knows targeted-test selection (see Test economy). |
| `reviewer` | inherit | read-only | Single agent, parameterized by lens: `bugs`, `security`, `performance`, `simplicity`. Prompt contains one shared rubric + per-lens checklist (security lens carries the OWASP list, performance lens carries N+1/bulk-op checks, etc.). Inherits the strongest session model deliberately — missed bugs are the #1 pain point; the cheap tier is used for the skeptic pass instead (see /octo:review). |
| `verifier` | haiku | all except Write/Edit | Evidence before "done": runs the app/endpoint/UI (curl, Playwright MCP when available), reports observed behavior vs expected. Absorbs qa-engineer-manual. |

Dropped: `research-engineer` (built-in web search + context7 MCP cover it) and
`database-engineer`/`security-engineer` as standing agents (now lenses).

## Skills

All skills are user-invocable with `argument-hint`. Shared conventions:
conventional commits, **never** any AI/Claude attribution in commits or PRs,
never push to protected branches, never `--no-verify`.

**Shared execution rules** (referenced by all skills):
- **File-disjoint**: two tasks are disjoint iff their planned file sets (from
  the plan's per-task file lists) do not intersect. Disjoint tasks run in
  parallel; tasks sharing any file run sequentially after the parallel batch.
- **Fan-out budget & partial failure**: parallel dispatches are capped (~10
  concurrent); if a lane fails or is throttled, retry it once, then continue
  with completed results and **report the gap** — no silent truncation, no
  half-done state presented as done.
- **Empty diff**: diff-driven skills (/test, /review) report "no changes
  detected" and exit; /test suggests `--all`.
- **Loop caps**: every loop has a numeric exit — build test loop max 5 cycles,
  review loop max 3 iterations, studio milestone max 2 re-plans — after which
  the skill stops and reports honestly rather than spinning.
- **Progress contract (pain point 6)**: on start, every multi-step skill
  registers its step plan in the native task list (TaskCreate), so the user
  watches a live checklist tick — never a bare spinner. Loops report
  `iteration k/cap` every cycle; fan-outs report `n/m lanes done` as lanes
  land. Long-running skills additionally write a one-line status to
  `.claude/octo/status.json` after each step (phase, step x/y, current
  activity) for the statusline. **No fake ETAs** — remaining steps and a size
  class (S/M/L) are honest; invented minutes are not.

### /octo:plan `<task>`
Architect agent explores (parallel Explore subagents for disjoint areas of a
large codebase), then produces a plan: numbered tasks with file paths, each
independently verifiable. Mandatory sections: `## Assumptions` (every
non-obvious decision, marked SAFE / RISKY) and `## Open Questions`. RISKY +
hard-to-reverse ⇒ the skill must stop and ask via AskUserQuestion before the
plan is final. Plan is saved to `.claude/plans/YYYY-MM-DD-<kebab-slug-from-task-title>.md` in the host project;
the skill adds `.claude/plans/` to `.git/info/exclude` (keeps plans out of
the repo without touching the project's .gitignore). Referenced by
/implement and /handoff.

### /octo:implement `[plan-file]`
Supervised mode. Executes the latest (or given) plan task-by-task: implementer
writes code, test-engineer adds tests for the task, targeted tests run, brief
report per task, user checkpoint between tasks. File-disjoint tasks are
dispatched to parallel implementer subagents in one message.

### /octo:build `<task>`
Autonomous mode — the whole loop, one command:
1. Read CLAUDE.md; run /octo:plan logic. **Assumption gate happens here** —
   all RISKY assumptions are resolved with the user up front, so the rest of
   the loop can run unattended.
2. Implement with tests, parallelizing file-disjoint tasks.
3. Targeted tests until green (max 5 fix cycles, then stop and report the
   failures — never claim done over a red suite).
4. /octo:review loop until clean (max 3 iterations, then report residuals).
5. Full-suite/lint final gate (respecting project weight config, below).
6. Offer /octo:pr.

### /octo:test `[scope]`
Test economy, the fix for pain point 2:
- Default: **targeted selection** — map `git diff` (working tree + branch vs
  base) to test files via project conventions: explicit mapping rules in the
  project's CLAUDE.md if present, else heuristics (mirrored test paths,
  same-name `test_*` files, test files importing the changed modules).
- `--all`: full suite.
- The skill prints which tests were selected and why, so silent gaps are
  visible ("selected 4 of 812 test files: ...").
- Project config (optional, in host CLAUDE.md): test command, how to run a
  subset, and a `weight: heavy|light` hint (rule of thumb: heavy = full suite
  over ~5 minutes) — heavy projects skip full-suite gates in /build unless
  explicitly requested.

### /octo:review `[--staged|--branch|<paths>]`
The fix for pain point 1. Loop:
1. Fan out reviewer subagents — one per lens (bugs, security, performance,
   simplicity) — **in a single message, in parallel**, over the diff.
2. Adversarial verification: each finding goes to a fresh skeptic subagent
   told to refute it; refuted findings are dropped (kills false-positive
   churn). Skeptic model scales with stakes: haiku for LOW/MEDIUM findings,
   **inherit for HIGH/CRITICAL** — a cheap skeptic must never be the reason a
   real security bug gets dismissed.
3. Confirmed findings are fixed (by implementer) — or only reported if the
   user invoked with `--report-only`.
4. Re-run the loop on the updated diff. Exit when a full pass returns zero
   confirmed findings, or after 3 iterations (report what remains).

### /octo:pr `[base]`
Generalized from the vwd version: detect base branch (explicit arg > repo
default), verify branch is not protected, run lint/pre-commit if configured,
push, `gh pr create` with description generated from commits + diff. Requires
`gh` (see Prerequisites); without it, falls back to push + printing the
compare URL for manual PR creation.
PR body always includes `## Assumptions` (carried from the plan) — pain
point 5's last line of defense. No AI attribution, ever.

### /octo:studio `<mission>` — client mode (end-to-end, zero confirmations)
For big, multi-day missions ("build a game") where the user is a *client*,
not a collaborator: one sign-off at the start, then the agents operate like a
studio — consulting each other instead of the user — until the result meets
acceptance criteria.

1. **Contract phase (the only confirmation).** The architect interviews the
   user once, deeply: goal, acceptance criteria ("done means…"), taste
   preferences, hard constraints, and — critically — an explicit **delegation
   of decision authority** ("all decisions not listed here are the studio's
   to make"). Optional budget/time limits. Written to
   `.claude/octo/run/contract.md`. User accepts → no further questions, ever.
2. **Consilium instead of the user.** Wherever other skills would stop and
   ask (RISKY assumptions, design forks, trade-offs), studio mode convenes a
   decision panel: three agents argue from fixed seats — *client advocate*
   (what would the client want, per the contract), *pragmatist* (simplest
   thing that ships), *risk* (what breaks later) — dispatched in parallel,
   then the **architect acts as judge** and rules (seat votes are advisory —
   the judge decides even on splits). Decision + votes + rationale are appended to
   `.claude/octo/run/decisions.md`. The client reads the minutes at delivery,
   not during.
3. **Milestone loop.** The mission is decomposed into demoable milestones on
   a board (`.claude/octo/run/board.md`). Per milestone: plan → parallel
   implement+test (file-disjoint fan-out) → targeted tests → review loop
   until clean → verifier actually runs/plays the artifact against the
   milestone's demo criteria. **Milestones are atomic**: each has a board
   status (PENDING / IN_PROGRESS / VERIFIED), advances only on verifier pass,
   and ends in a git commit — on resume, an IN_PROGRESS milestone restarts
   from the last committed state, never from half-written files. A milestone
   that fails twice is re-planned by consilium (descope or mark blocked,
   logged); after 2 re-plans it's parked in the delivery report.
4. **Built to survive days.** All state lives on disk (contract, board,
   decisions, journal) — any fresh session resumes with
   `/octo:studio --resume`, and the context-restore hook surfaces the active
   run after every compaction. A studio run is interruptible by design; it
   never depends on one session staying alive. If `--resume` finds state files
   missing or malformed, it halts and reports to the user — corrupt state is
   the one situation where the studio is allowed to break the no-questions
   rule rather than guess.
5. **Delivery.** Final acceptance pass by the verifier against the contract's
   criteria, then a delivery report: what was built, how to run it, the
   decision minutes, known limitations. The client's next input is the first
   one since sign-off: accept, or file change requests (which start a new,
   smaller studio run).

Relationship to /octo:build: build is autonomous for a *task* (hours,
assumption gate up front, user nearby); studio is autonomous for a *mission*
(days, decision authority delegated, user absent). Studio composes the same
machinery — plan/review/test/debug/lessons all apply per milestone.

### /octo:debug `<bug description>`
Systematic root-cause loop — no fix without a confirmed cause and a repro:
1. **Reproduce first**: build a minimal repro, ideally as a failing test.
2. Form ranked hypotheses; investigate independent hypotheses with parallel
   subagents (one message, one subagent per hypothesis).
3. Falsify with evidence (instrumentation, bisect, logs) until one hypothesis
   survives.
4. Fix the root cause, not the symptom; the repro test stays as a regression
   test.
5. Record a lesson (see Lessons engine) so the same class of bug is caught at
   review time next time.

### /octo:skill `<what you want>`
Meta-skill: author new skills, agents, or hooks — either into the octo repo
itself or into a host project's `.claude/`. Knows current frontmatter formats,
hook events, and plugin layout; scaffolds the artifact, dry-runs it, and (for
octo additions) commits in the plugin repo. The plugin extends itself.

### /octo:retro
Post-mortem for the session: mines the conversation for user corrections,
review findings that were confirmed, and debugging root causes; distills them
into lesson cards; merges duplicates and prunes stale ones. Run at the end of
significant sessions or after a bug escapes to production.

### /octo:handoff
Writes `.claude/handoff.md` in the host project: current goal, done/remaining
tasks, key decisions + assumptions, gotchas discovered, next step. The
context-restore hook points at this file after compaction; new sessions can
start with "read the handoff".

## Lessons engine (the differentiator)

**Every bug leaves a scar; the plugin remembers.** Most review tooling starts
every review from zero. Octo accumulates *project-specific* failure knowledge
and feeds it back into every future plan, implementation, and review — the
review checklist is literally generated from the bugs that actually happened
in this codebase.

- **Storage**: `.claude/octo/lessons/*.md` in the host project — small cards:
  the failure pattern, a real example (file:line at time of writing), and how
  to catch it. Optional `~/.claude/octo/lessons/` for cross-project habits
  (e.g. "I always forget timezone handling").
- **Writers**: `/octo:review` (every finding that survives adversarial
  verification becomes a lesson candidate), `/octo:debug` (every root cause),
  `/octo:retro` (user corrections mined from the session; also the curator —
  dedups, merges, prunes).
- **Readers**: `reviewer` lenses load matching lessons before reviewing (your
  bug history becomes the checklist), `implementer` loads them before writing
  (known failure patterns avoided up front), `architect` at planning time.
- **Curation over accumulation — quantified**: a card is ≤25 lines; max 50
  cards per project, 20 global. Readers never load everything: **top 15 cards**
  ranked by path/topic relevance to the current diff + recency. When a writer
  pushes the count over cap, it triggers an inline mini-retro (merge/prune)
  before adding. A lessons folder that grows unbounded is context bloat — the
  thing this plugin exists to fight.

The compounding effect targets pain point 1 directly: a class of bug only has
to escape review once — after that it's part of the machine.

## Hooks (`hooks/hooks.json`)

| Event | Matcher | Script | Behavior |
|---|---|---|---|
| PreToolUse | `Bash` | `guard.sh` | Blocks (exit 2): push to protected branches, force-push, `--no-verify`, `git reset --hard`, `rm -rf` on root/cwd/src, and destructive SQL passed to a DB CLI (`psql|mysql|sqlite3 … -c/-e` or via `docker exec` containing `DROP TABLE|DROP DATABASE|TRUNCATE|DELETE FROM`). Protected branches = `main master staging production qa develop` ∪ repo default branch, overridable via `.claude/octo.json`. Also intercepts `manage.py dbshell`-style direct DB shells. After built-in checks it sources `.claude/hooks/guard-extra.sh` if the host project has one — this is how vwd keeps its AWS-profile and manage.py rules. **Honesty clause**: the guard is regex-based defense-in-depth, not a sandbox — it does not catch SQL hidden in shell variables or heredocs; the README documents these known bypass limits so it never creates false confidence. |
| PostToolUse | `Edit\|Write` | `auto-format.sh` | Formats **only the edited file** if a formatter is detected (ruff → pyproject/ruff.toml; prettier → package.json; gofmt; rustfmt). Fast, file-scoped, keeps diffs clean before review. Missing/failing formatter → silent skip with a log line, never blocks the edit. Trade-off noted: an external format can occasionally invalidate the next Edit's old_string; accepted, standard pattern. |
| SessionStart | `compact\|resume` | `context-restore.sh` | Fix for pain point 4 — the old `on-compact.sh` was never wired. Re-injects: current branch, dirty files, last 5 commits, critical rules (no protected-branch push, no --no-verify), and the first 30 lines of `.claude/handoff.md` if present. |
| Stop | — | `verify-done.sh` | Non-blocking notice: if source files were modified this session but the transcript shows no test/lint run, emit a one-line reminder. Deliberately gentle — a hard block here causes more friction than it saves. |

## Prerequisites

| Dependency | Required? | Degradation if absent |
|---|---|---|
| `git` | hard | — |
| `gh` CLI | for /octo:pr | push + print compare URL for manual PR |
| `jq` | for hooks | guard falls back to grep-only parsing |
| Formatter (ruff/prettier/…) | optional | auto-format silently skips |
| Playwright MCP | optional | verifier degrades to curl/CLI checks |
| Host CLAUDE.md | recommended | detected defaults + explicit warning (see agent preamble) |

## Per-project configuration surface

Everything project-specific lives in the **host project**, read by the plugin:

- `CLAUDE.md` — stack rules, test command + subset syntax + weight, review
  no-gos, protected branches if unusual.
- `.claude/octo.json` (optional) — protected-branch override list.
- `.claude/hooks/guard-extra.sh` (optional) — extra PreToolUse rules.
- `.claude/handoff.md` — written by /octo:handoff, read by context-restore.
- `.claude/octo/lessons/` — written by /review, /debug, /retro; read by
  reviewer, implementer, architect.
- `.claude/octo/status.json` — one-line progress state (phase, step x/y,
  current activity); written by long-running skills, rendered by the optional
  statusline script (opt-in via `statusLine` in user settings; README shows
  the one-liner).

## vwd-backend migration (phase 2, after plugin works)

- Delete from `vwd-backend/.claude/`: all 9 agents, `test/`, `review/`, `pr/`
  skills, both hooks (replaced by plugin equivalents).
- Keep: `cio`, `seed-demo`, `document-feature`, `publish-report`,
  `sentry-review`, `sentry-fix` skills; permission allow/deny lists.
- Add: `.claude/hooks/guard-extra.sh` with the AWS-profile allowlist,
  `manage.py flush/migrate --fake` and docker-SQL rules from the old guard.
- Move agent knowledge worth keeping (CustomTestCase rules, dual-pipeline
  notes, scale numbers) into vwd's `CLAUDE.md` where all tools see it.
- Prune `settings.local.json` (dozens of stale one-off entries); re-run
  `/fewer-permission-prompts` (Claude Code built-in) to rebuild a clean
  allowlist.

## Recommendations outside the plugin

- **Context bloat**: with octo self-contained, disable superpowers, epsilon,
  and epsilon-dev (`/plugin`) — their skill/agent lists consume a meaningful
  slice of every session's context window, which feeds the context-decay
  problem. Re-enable selectively if missed.
- **Keep**: context7 (docs lookup), Playwright MCP (verifier uses it).
- **Use built-ins instead of custom**: `/code-review ultra` (Claude Code
  built-in) for deep pre-merge reviews of big branches; native plan mode for
  quick planning when the full /octo:plan ceremony is overkill.
- **Parallel sessions**: for independent tasks, use worktree-isolated
  subagents (already available via Agent tool `isolation: "worktree"`) rather
  than serializing in one session.

## Non-goals

- No stack packs (django.md/react.md) in v1 — CLAUDE.md carries stack rules.
- No CI integration, no team distribution concerns — personal plugin.
- No replacement for project-specific skills (cio, seed-demo, …).

## Rollout order

1. Scaffold repo: plugin.json, marketplace.json, README.
2. Hooks (guard, auto-format, context-restore, verify-done) + hooks.json.
3. Agents (architect, implementer, test-engineer, reviewer, verifier).
4. Skills (plan, implement, test, review, debug, pr, handoff, retro, skill,
   build, studio — build and studio last, they compose the others). Lessons
   engine lands with review/debug/retro.
5. Install into a scratch project; run the acceptance scenarios below.
6. Install into vwd-backend; run migration (slim .claude, guard-extra.sh,
   CLAUDE.md updates).

## Acceptance scenarios (rollout step 5)

Each hook: one pass + one block/degrade case. Each skill: one happy path.

| Artifact | Scenario | Expected |
|---|---|---|
| guard.sh | `git push --force`, push to `main`, `--no-verify`, `psql -c "DROP TABLE x"` | exit 2 with reason |
| guard.sh | `git push origin feat/x`, `aws sso login` | allowed |
| guard.sh | project guard-extra.sh present | sourced and enforced |
| auto-format.sh | edit .py in ruff project | file formatted |
| auto-format.sh | formatter binary absent | edit succeeds, hook skips |
| context-restore.sh | trigger compaction (or `/compact`) | branch/rules/handoff re-injected |
| verify-done.sh | edit source, end turn without tests | one-line notice, non-blocking |
| /octo:plan | small task in scratch repo | plan file with Assumptions + Open Questions |
| /octo:test | one changed file | targeted subset selected + printed rationale |
| /octo:review | diff with a seeded bug | bug found, skeptic-confirmed, fixed, loop exits clean |
| /octo:debug | seeded failing behavior | repro test → root cause → fix → lesson written |
| /octo:build | small feature | plan→code→tests→review→green, assumptions gated up front |
| /octo:pr | feature branch | PR with Assumptions section, no AI attribution |
| /octo:studio | toy mission (e.g. CLI game) | contract → milestones VERIFIED → decisions.md populated → delivery report; `--resume` mid-run works |
| /octo:retro | session with corrections | lesson cards created, duplicates merged |
| Progress contract | any /octo:build run | task-list checklist visible from step 1; status.json updated per step; loop ticks show k/cap |
| CLAUDE.md absent | /octo:build in bare repo | explicit warning + offer to scaffold, no silent defaults |
