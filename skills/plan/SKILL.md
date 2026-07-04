---
name: plan
description: Explore the codebase and produce an implementation plan with numbered, independently verifiable tasks. Surfaces every assumption (SAFE/RISKY); RISKY + hard-to-reverse decisions come back as questions before the plan is final.
argument-hint: "<task description>"
---

## Progress Contract

Register these steps as a task list before doing any work. After each step, update
`.claude/octo/status.json` with `{"phase": <step-name>, "step": <N>, "activity": <short-string>}`.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Steps: (1) read-project-context, (2) register-progress, (3) explore,
(4) author-plan, (5) assumption-gate, (6) save-and-register.

## Workflow

### Step 1 — Read project context

Read the host project's `CLAUDE.md`. If it is absent or missing a needed section:

- State what is missing explicitly.
- Offer to scaffold a minimal `CLAUDE.md` and wait for the user's answer before proceeding.
- Detect what you can from repo artifacts (lockfiles, `Makefile`, `pyproject.toml`, CI config,
  `package.json`). Label every inferred convention `[DETECTED]`.

Update status: `{"phase": "read-project-context", "step": 1, "activity": "read CLAUDE.md"}`.

### Step 2 — Register progress

Create the native task list for this session (all six steps). This is the single source of
truth for human-visible progress — do not maintain a separate running log.

Update status: `{"phase": "register-progress", "step": 2, "activity": "task list created"}`.

### Step 3 — Explore

**Division of labor**: this skill owns orchestration, gates, and file I/O. The architect agent
owns thinking and plan text. Do not duplicate architect reasoning here.

Partition the codebase into disjoint domains. Dispatch up to **10 parallel Explore or architect
subagents** in a single message (one tool-use block per agent). Serial exploration is not
acceptable when parallel dispatch halves elapsed time.

**Retry rule**: if a subagent returns empty or contradictory findings, retry it once with a
narrower scope. After one retry, report the gap in `## Open Questions` rather than blocking.

If two subagents return contradictory findings about the same area, surface the conflict in Open
Questions — never resolve it silently.

Update status: `{"phase": "explore", "step": 3, "activity": "parallel subagents dispatched"}`.

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

Update status: `{"phase": "author-plan", "step": 4, "activity": "architect agent complete"}`.

### Step 5 — Assumption gate  ← STOP

Scan the `## Assumptions` section for any item marked `RISKY` where the consequence is also
**hard to reverse** (e.g. schema migrations, public API removals, irreversible data transforms).

**If any such item exists**: STOP. Do not save the plan. Present each blocker to the user as a
clear question (AskUserQuestion or equivalent). Wait for answers. Update the plan's Assumptions
and Open Questions accordingly, then continue to Step 6.

If no RISKY + hard-to-reverse items exist, proceed immediately.

Update status: `{"phase": "assumption-gate", "step": 5, "activity": "gate cleared or awaiting user"}`.

### Step 6 — Save and register

1. Derive the slug: lower-case the task title, replace spaces and special characters with `-`,
   collapse runs of `-`. Example: `"Add OAuth flow"` → `add-oauth-flow`.

2. Write the plan to `.claude/plans/YYYY-MM-DD-<slug>.md` using today's date.

3. Register `.claude/plans/` in `.git/info/exclude`: read the file, append the line
   `.claude/plans/` **only if it is not already present**. Never modify the project's
   `.gitignore`.

4. Report the saved path and the total step count to the user.

Update status: `{"phase": "save-and-register", "step": 6, "activity": "plan saved"}`.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (`main`, `master`, `qa`, `staging`).
- Never use `--no-verify` or force-push.
- Fan-out cap: **10 parallel lanes**; retry once, then report the gap.
