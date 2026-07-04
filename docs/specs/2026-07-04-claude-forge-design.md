# claude-forge — Personal Claude Code Plugin (Design)

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

## Contract (refined prompt)

- New git repo at `~/PycharmProjects/claude-forge/`, structured as an
  installable plugin with its own marketplace file
  (`/plugin marketplace add <repo>` works from GitHub or local path).
- **Self-contained**: the full dev cycle is covered; superpowers/epsilon become
  optional.
- **Stack-agnostic**: the plugin carries universal engineering discipline;
  every agent reads the host project's `CLAUDE.md` for stack rules before
  acting. No Django/vwd specifics in the plugin.
- **Dual-mode**: per task the user chooses `/forge:build` (autonomous full
  loop) or individual skills step-by-step.
- Separately: slim `vwd-backend/.claude/` to only project-specific pieces and
  clean permission cruft (migration section below).

## Repo layout

```
claude-forge/
  .claude-plugin/
    plugin.json            # name "forge", version, author
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
    pr/SKILL.md
    handoff/SKILL.md
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
and conventions. Project instructions override your defaults."* Specializations
that were separate agents (API design, DB tuning, security) become **review
lenses and planning checklists**, not standing agents — fewer agents means less
context bloat and makes parallel lens fan-out affordable.

| Agent | Model | Tools | Role |
|---|---|---|---|
| `architect` | inherit | read-only | Planning, system/API design, codebase exploration. Every plan ends with `## Assumptions` and `## Open Questions`. Absorbs software-architect + api-designer. |
| `implementer` | inherit | all | Production code. Discipline: simplicity over cleverness, focused diffs, follow existing patterns, no drive-by refactors. Never writes tests (role separation kept from old setup). |
| `test-engineer` | inherit | all | Writes/repairs tests following project conventions discovered from CLAUDE.md + existing tests. Knows targeted-test selection (see Test economy). |
| `reviewer` | inherit | read-only | Single agent, parameterized by lens: `bugs`, `security`, `performance`, `simplicity`. Prompt contains one shared rubric + per-lens checklist (security lens carries the OWASP list, performance lens carries N+1/bulk-op checks, etc.). Inherits the strongest session model deliberately — missed bugs are the #1 pain point; the cheap tier is used for the skeptic pass instead (see /forge:review). |
| `verifier` | haiku | all except Write/Edit | Evidence before "done": runs the app/endpoint/UI (curl, Playwright MCP when available), reports observed behavior vs expected. Absorbs qa-engineer-manual. |

Dropped: `research-engineer` (built-in web search + context7 MCP cover it) and
`database-engineer`/`security-engineer` as standing agents (now lenses).

## Skills

All skills are user-invocable with `argument-hint`. Shared conventions:
conventional commits, **never** any AI/Claude attribution in commits or PRs,
never push to protected branches, never `--no-verify`.

### /forge:plan `<task>`
Architect agent explores (parallel Explore subagents for disjoint areas of a
large codebase), then produces a plan: numbered tasks with file paths, each
independently verifiable. Mandatory sections: `## Assumptions` (every
non-obvious decision, marked SAFE / RISKY) and `## Open Questions`. RISKY +
hard-to-reverse ⇒ the skill must stop and ask via AskUserQuestion before the
plan is final. Plan is saved to `.claude/plans/<date>-<slug>.md` in the host project;
the skill adds `.claude/plans/` to `.git/info/exclude` (keeps plans out of
the repo without touching the project's .gitignore). Referenced by
/implement and /handoff.

### /forge:implement `[plan-file]`
Supervised mode. Executes the latest (or given) plan task-by-task: implementer
writes code, test-engineer adds tests for the task, targeted tests run, brief
report per task, user checkpoint between tasks. File-disjoint tasks are
dispatched to parallel implementer subagents in one message.

### /forge:build `<task>`
Autonomous mode — the whole loop, one command:
1. Read CLAUDE.md; run /forge:plan logic. **Assumption gate happens here** —
   all RISKY assumptions are resolved with the user up front, so the rest of
   the loop can run unattended.
2. Implement with tests, parallelizing file-disjoint tasks.
3. Targeted tests until green.
4. /forge:review loop until clean (max 3 iterations, then report residuals).
5. Full-suite/lint final gate (respecting project weight config, below).
6. Offer /forge:pr.

### /forge:test `[scope]`
Test economy, the fix for pain point 2:
- Default: **targeted selection** — map `git diff` (working tree + branch vs
  base) to test files via project conventions: explicit mapping rules in the
  project's CLAUDE.md if present, else heuristics (mirrored test paths,
  same-name `test_*` files, test files importing the changed modules).
- `--all`: full suite.
- The skill prints which tests were selected and why, so silent gaps are
  visible ("selected 4 of 812 test files: ...").
- Project config (optional, in host CLAUDE.md): test command, how to run a
  subset, and a `weight: heavy|light` hint — heavy projects skip full-suite
  gates in /build unless explicitly requested.

### /forge:review `[--staged|--branch|<paths>]`
The fix for pain point 1. Loop:
1. Fan out reviewer subagents — one per lens (bugs, security, performance,
   simplicity) — **in a single message, in parallel**, over the diff.
2. Adversarial verification: each finding goes to a fresh skeptic subagent
   (cheap model — haiku) told to refute it; refuted findings are dropped
   (kills false-positive churn).
3. Confirmed findings are fixed (by implementer) — or only reported if the
   user invoked with `--report-only`.
4. Re-run the loop on the updated diff. Exit when a full pass returns zero
   confirmed findings, or after 3 iterations (report what remains).

### /forge:pr `[base]`
Generalized from the vwd version: detect base branch (explicit arg > repo
default), verify branch is not protected, run lint/pre-commit if configured,
push, `gh pr create` with description generated from commits + diff.
PR body always includes `## Assumptions` (carried from the plan) — pain
point 5's last line of defense. No AI attribution, ever.

### /forge:debug `<bug description>`
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

### /forge:skill `<what you want>`
Meta-skill: author new skills, agents, or hooks — either into the forge repo
itself or into a host project's `.claude/`. Knows current frontmatter formats,
hook events, and plugin layout; scaffolds the artifact, dry-runs it, and (for
forge additions) commits in the plugin repo. The plugin extends itself.

### /forge:retro
Post-mortem for the session: mines the conversation for user corrections,
review findings that were confirmed, and debugging root causes; distills them
into lesson cards; merges duplicates and prunes stale ones. Run at the end of
significant sessions or after a bug escapes to production.

### /forge:handoff
Writes `.claude/handoff.md` in the host project: current goal, done/remaining
tasks, key decisions + assumptions, gotchas discovered, next step. The
context-restore hook points at this file after compaction; new sessions can
start with "read the handoff".

## Lessons engine (the differentiator)

**Every bug leaves a scar; the plugin remembers.** Most review tooling starts
every review from zero. Forge accumulates *project-specific* failure knowledge
and feeds it back into every future plan, implementation, and review — the
review checklist is literally generated from the bugs that actually happened
in this codebase.

- **Storage**: `.claude/forge/lessons/*.md` in the host project — small cards:
  the failure pattern, a real example (file:line at time of writing), and how
  to catch it. Optional `~/.claude/forge/lessons/` for cross-project habits
  (e.g. "I always forget timezone handling").
- **Writers**: `/forge:review` (every finding that survives adversarial
  verification becomes a lesson candidate), `/forge:debug` (every root cause),
  `/forge:retro` (user corrections mined from the session; also the curator —
  dedups, merges, prunes).
- **Readers**: `reviewer` lenses load matching lessons before reviewing (your
  bug history becomes the checklist), `implementer` loads them before writing
  (known failure patterns avoided up front), `architect` at planning time.
- **Curation over accumulation**: lessons are capped and card-sized; /retro
  merges near-duplicates and deletes lessons the codebase has outgrown. A
  lessons folder that grows unbounded is context bloat — the thing this
  plugin exists to fight.

The compounding effect targets pain point 1 directly: a class of bug only has
to escape review once — after that it's part of the machine.

## Hooks (`hooks/hooks.json`)

| Event | Matcher | Script | Behavior |
|---|---|---|---|
| PreToolUse | `Bash` | `guard.sh` | Blocks (exit 2): push to protected branches, force-push, `--no-verify`, `git reset --hard`, `rm -rf` on root/cwd/src, and destructive SQL passed to a DB CLI (`psql|mysql|sqlite3 … -c/-e` or via `docker exec` containing `DROP TABLE|DROP DATABASE|TRUNCATE|DELETE FROM`). Protected branches = `main master staging production qa develop` ∪ repo default branch, overridable via `.claude/forge.json`. After built-in checks it sources `.claude/hooks/guard-extra.sh` if the host project has one — this is how vwd keeps its AWS-profile and manage.py rules. |
| PostToolUse | `Edit\|Write` | `auto-format.sh` | Formats **only the edited file** if a formatter is detected (ruff → pyproject/ruff.toml; prettier → package.json; gofmt; rustfmt). Fast, file-scoped, keeps diffs clean before review. Trade-off noted: an external format can occasionally invalidate the next Edit's old_string; accepted, standard pattern. |
| SessionStart | `compact\|resume` | `context-restore.sh` | Fix for pain point 4 — the old `on-compact.sh` was never wired. Re-injects: current branch, dirty files, last 5 commits, critical rules (no protected-branch push, no --no-verify), and the first 30 lines of `.claude/handoff.md` if present. |
| Stop | — | `verify-done.sh` | Non-blocking notice: if source files were modified this session but the transcript shows no test/lint run, emit a one-line reminder. Deliberately gentle — a hard block here causes more friction than it saves. |

## Per-project configuration surface

Everything project-specific lives in the **host project**, read by the plugin:

- `CLAUDE.md` — stack rules, test command + subset syntax + weight, review
  no-gos, protected branches if unusual.
- `.claude/forge.json` (optional) — protected-branch override list.
- `.claude/hooks/guard-extra.sh` (optional) — extra PreToolUse rules.
- `.claude/handoff.md` — written by /forge:handoff, read by context-restore.
- `.claude/forge/lessons/` — written by /review, /debug, /retro; read by
  reviewer, implementer, architect.

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
  `/fewer-permission-prompts` to rebuild a clean allowlist.

## Recommendations outside the plugin

- **Context bloat**: with forge self-contained, disable superpowers, epsilon,
  and epsilon-dev (`/plugin`) — their skill/agent lists consume a meaningful
  slice of every session's context window, which feeds the context-decay
  problem. Re-enable selectively if missed.
- **Keep**: context7 (docs lookup), Playwright MCP (verifier uses it).
- **Use built-ins instead of custom**: `/code-review ultra` for deep pre-merge
  reviews of big branches; native plan mode for quick planning when the full
  /forge:plan ceremony is overkill.
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
   build — build last, it composes the others). Lessons engine lands with
   review/debug/retro.
5. Install into a scratch project; smoke-test each hook and skill.
6. Install into vwd-backend; run migration (slim .claude, guard-extra.sh,
   CLAUDE.md updates).
