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
(4) author-plan, (5) plan-self-review, (6) assumption-gate, (7) save-and-register.

## Arguments

- **`<task description>`** — what to plan. If `.claude/octo/specs/` contains a spec for this
  work (or the user names one explicitly), the plan **MUST** consume it: load the spec before
  exploration, carry every `## Assumptions` item forward into the plan's own Assumptions
  section, and ensure every spec requirement maps to at least one Implementation Step.

## Workflow

### Step 1 — Read project context

Read the host project's `CLAUDE.md`. If it is absent or missing a needed section:

- State what is missing explicitly.
- Offer to scaffold a minimal `CLAUDE.md` and wait for the user's answer before proceeding.
- Detect what you can from repo artifacts (lockfiles, `Makefile`, `pyproject.toml`, CI config,
  `package.json`). Label every inferred convention `[DETECTED]`.


### Step 2 — Register progress

Create the native task list for this session (all seven steps). This is the single source of
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

Dispatch the **architect agent** with the task description, all exploration findings, any
relevant spec from `.claude/octo/specs/`, and any lessons from `.claude/octo/lessons/*.md`.
The architect produces:

1. **Context** — what was read and explored; which lessons were relevant; which spec (if any)
   was consumed.
2. **Design** — approach, architecture decisions, trade-offs.
3. **Implementation Steps** — numbered, atomic; each step MUST include:
   - **Exact file paths** for every file to be created or modified.
   - **TDD steps in order**: write failing test → run to confirm it fails → implement minimally
     → run to confirm it passes → commit with a conventional message.
   - **`Interfaces:`** block — consumes and produces, with exact names and signatures so the
     task can be executed by a fresh agent without reading sibling tasks.
   - **Verification command** with expected output — a command that, when run after the task,
     confirms it is complete.
   - **No-placeholders rule**: TBD, "add error handling", "similar to task N", or steps without
     concrete content are plan defects. Every step must have complete, actionable content.
4. **API/Schema Checklist** (when applicable).
5. **`## Assumptions`** — every non-obvious decision marked `SAFE` or `RISKY`; if a spec was
   consumed, all spec Assumptions are carried here verbatim.
6. **`## Open Questions`** — specific questions with who owns the answer and what the plan does
   in each case.

Do not restate the architect's output — use it verbatim as the plan body.


### Step 5 — Plan self-review

Before presenting the assumption gate, scan the plan for defects:

1. **Spec coverage** (if a spec was consumed) — every spec requirement maps to at least one
   numbered Implementation Step; flag any requirement without a matching step.
2. **Placeholder scan** — no TBD, TODO, "add error handling", "similar to task N", or blank
   acceptance criteria anywhere in the Implementation Steps.
3. **Interface consistency** — the `Interfaces:` block of each step lists outputs that are
   consumed by later steps; verify names and signatures are consistent across the chain.

Fix all defects inline before proceeding. Do not present the assumption gate over a plan that
fails any of these checks.


### Step 6 — Assumption gate  ← STOP

Scan the `## Assumptions` section for any item marked `RISKY` where the consequence is also
**hard to reverse** (e.g. schema migrations, public API removals, irreversible data transforms).

**If any such item exists**: STOP. Do not save the plan. Present RISKY assumptions via AskUserQuestion: one question per assumption, the options being the concrete alternatives (recommended option first, labeled '(Recommended)'); never a prose wall. Wait for answers. Update the plan's Assumptions and Open Questions accordingly, then continue to Step 7.

If no RISKY + hard-to-reverse items exist, proceed immediately.


### Step 7 — Save and register

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
- Reader-first output: lead with the outcome in one sentence; keep the visible reply short and dev-readable — only what changes the reader's next action. Full detail (complete reports, evidence, logs) goes to a file under `.claude/octo/reports/YYYY-MM-DD-<skill>-<slug>.md` with the path given in chat — never dumped into the conversation.
