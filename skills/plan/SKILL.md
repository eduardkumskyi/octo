---
name: plan
description: Explore the codebase and produce an implementation plan with numbered, independently verifiable tasks. Surfaces every assumption (SAFE/RISKY); RISKY + hard-to-reverse decisions come back as questions before the plan is final.
argument-hint: "<task description>"
---

## Progress Contract

Register these steps as a native task list at Step 2, before beginning exploration.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to in_progress/completed as you go — the checklist is the user's primary progress view.

Steps: (1) read-project-context, (2) register-progress, (3) explore,
(4) author-plan, (5) assumption-gate, (6) save-and-register.

## Workflow

### Step 1 — Read project context

Read the host project's `CLAUDE.md`. If it is absent or missing a needed section:

- State what is missing explicitly.
- Offer to scaffold a minimal `CLAUDE.md` and wait for the user's answer before proceeding.
- Detect what you can from repo artifacts (lockfiles, `Makefile`, `pyproject.toml`, CI config,
  `package.json`). Label every inferred convention `[DETECTED]`.


### Step 2 — Register progress

Create the native task list for this session (all six steps). This is the single source of
truth for human-visible progress — do not maintain a separate running log.


### Step 3 — Explore

**Division of labor**: this skill owns orchestration, gates, and file I/O. The architect agent
owns thinking and plan text. Do not duplicate architect reasoning here.

Partition the codebase into disjoint domains. Dispatch up to **10 parallel Explore or architect
subagents** in a single message (one tool-use block per agent) — this MUST be a single message;
serial exploration when parallel dispatch is possible is a defect, not a style choice.

**Retry rule**: if a subagent returns empty or contradictory findings, retry it once with a
narrower scope. After one retry, report the gap in `## Open Questions` rather than blocking.

If two subagents return contradictory findings about the same area, surface the conflict in Open
Questions — never resolve it silently.


### Step 4 — Author the plan

Dispatch the **architect agent** with the task description, all exploration findings, and any
lessons from `.claude/octo/lessons/*.md`. The architect produces:

1. **Context** — what was read and explored; which lessons were relevant.
2. **Design** — approach, architecture decisions, trade-offs.
3. **Implementation Steps** — numbered, atomic; each lists affected files and an acceptance
   criterion so any step can be verified independently.
4. **API/Schema Checklist** (when applicable).
5. **`## Assumptions`** — every non-obvious decision marked `SAFE` or `RISKY`.
6. **`## Open Questions`** — specific questions with who owns the answer and what the plan does
   in each case.

Do not restate the architect's output — use it verbatim as the plan body.


### Step 5 — Assumption gate  ← STOP

Scan the `## Assumptions` section for any item marked `RISKY` where the consequence is also
**hard to reverse** (e.g. schema migrations, public API removals, irreversible data transforms).

**If any such item exists**: STOP. Do not save the plan. Present RISKY assumptions via AskUserQuestion: one question per assumption, the options being the concrete alternatives (recommended option first, labeled '(Recommended)'); never a prose wall. Wait for answers. Update the plan's Assumptions and Open Questions accordingly, then continue to Step 6.

If no RISKY + hard-to-reverse items exist, proceed immediately.


### Step 6 — Save and register

1. Derive the slug: lower-case the task title, replace spaces and special characters with `-`,
   collapse runs of `-`. Example: `"Add OAuth flow"` → `add-oauth-flow`.

2. Write the plan to `.claude/plans/YYYY-MM-DD-<slug>.md` using today's date.

3. Register `.claude/plans/` in `.git/info/exclude`: read the file (create the file if it does not exist), append the line
   `.claude/plans/` **only if it is not already present**. Never modify the project's
   `.gitignore`.

4. Report the saved path and the total step count to the user.


---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Parallel-first: dispatches that do not consume each other's output MUST go in a single
  message. Dispatching sequentially what could run concurrently is a defect, not a style
  choice. Cap ≈10 concurrent lanes; more work than lanes → batch waves.
