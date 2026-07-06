---
name: go
description: "The front door: describe what you want in a sentence — octo sizes the ceremony automatically. Small fix → implement + verify in minutes; feature → full build; subsystem → spec, plan, then build. Announces the chosen gear; override with -s/-m/-l."
argument-hint: "<task description> [-s|-m|-l]"
---

## Progress Contract

**OCTO_ROOT** = `${CLAUDE_PLUGIN_ROOT}` when set; otherwise two directories above this skill's base directory (`skills/<name>/` sits at `<plugin-root>/skills/<name>/`). Resolve once at start.

Register steps as a native task list before doing any work.
Report progress as "N steps remaining" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to in_progress/completed as you go — the checklist is the user's primary progress view.

Steps: (1) read-context, (2) classify, (3) route.

## Arguments

- **`<task description>`** — what to do. Required; if omitted, ask once then proceed.
- **`-s`** — force Small gear.
- **`-m`** — force Medium gear.
- **`-l`** — force Large gear.

## Workflow

### Step 1 — Read context

Read the host project's `CLAUDE.md`. If absent, detect conventions from repo artifacts
(`pyproject.toml`, `Makefile`, `package.json`, CI config) and label them `[DETECTED]`.

### Step 2 — Classify

If a gear flag (`-s`, `-m`, `-l`) is present, use it and skip classification.

Otherwise, classify the task into one of three gears:

| Gear | Definition |
|------|-----------|
| **S — Small** | Localized change, ≤2 files, no design decisions needed (typo, config tweak, small bug) |
| **M — Medium** | A feature with tests but a clear shape — no upfront design session needed |
| **L — Large** | New subsystem, multiple components, or design decisions needed before building |

Announce the chosen gear before routing:

> `Gear: M — <one-line reason>. Override with -s/-m/-l.`

### Step 3 — Route

#### Gear S — Small

Dispatch one **implementer subagent** with the task. If the change affects behavior (not
just whitespace or config comments), also dispatch one **test-engineer subagent** in the
same message — parallel-first applies here.

Pass each subagent: the task description, detected CLAUDE.md conventions, and any
relevant lessons from `.claude/octo/lessons/*.md`.

Run targeted tests using `/octo:test` selection logic: map changed files to test files via
CLAUDE.md rules, mirrored paths, same-name matches, and import heuristics. Print the
selection and rationale before running.

On green, make a conventional commit: `type(scope): <brief description>`.

End the chat output with a **Try it** block produced from verifier or test-run evidence:
the exact command(s) the user can run to see the result, plus the observed output
(one–two lines). No delivery without a try-it.

#### Gear M — Medium

Run the full `/octo:build` workflow. Reader-first and try-it rules from that skill apply.

#### Gear L — Large

Run `/octo:spec` first, then `/octo:plan`, then `/octo:build`. Each step's own gates and
unattended rules apply in full.

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
