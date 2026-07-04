---
name: implement
description: "Supervised execution of a plan task-by-task: implementer writes code, test-engineer adds tests, targeted tests run, user checkpoint between batches. File-disjoint tasks run in parallel."
argument-hint: "[plan-file]"
---

## Progress Contract

Register these steps as a native task list at Step 2, immediately after the plan is resolved. After each step, update
`.claude/octo/status.json` with `{"phase": <step-name>, "step": <N>, "activity": <short-string>}`.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Steps: (1) resolve-plan, (2) register-progress, (3) partition-tasks, then per batch:
(4) implement-batch, (5) test-batch, (6) run-tests, (7) checkpoint; finally (8) conclude.

## Arguments

- **`[plan-file]`** — path to a plan file. If omitted, use the latest file in `.claude/plans/`
  by name (lexicographic sort; names are `YYYY-MM-DD-<slug>.md`). If no plans directory exists
  or it is empty, abort and tell the user to run `/octo:plan` first.

## Workflow

### Step 1 — Resolve plan

Find the plan: use the explicit arg if given; otherwise list `.claude/plans/`, sort by name,
pick the last entry. Print the resolved path.

Update status: `{"phase": "resolve-plan", "step": 1, "activity": "plan resolved"}`.

### Step 2 — Register progress

Create the native task list for this session. For each plan task, create one native task entry.
This is the single source of truth for human-visible progress.

Update status: `{"phase": "register-progress", "step": 2, "activity": "task list created"}`.

### Step 3 — Partition tasks

Read all tasks from the plan. For each task, collect its **affected files** list (from the
plan's Implementation Steps). Two tasks are **file-disjoint** if their affected-file sets do
not intersect. Group consecutive file-disjoint tasks into a single parallel batch; tasks
sharing files with any in-progress batch are deferred until that batch completes.

Update status: `{"phase": "partition-tasks", "step": 3, "activity": "batches formed"}`.

### Step 4 — Implement batch

Dispatch **one implementer subagent per task in the current batch** in a single message
(fan-out cap: 10 lanes). Pass each subagent: the plan, its specific task, the affected files,
and relevant lessons from `.claude/octo/lessons/*.md`.

**Failure rule**: if a lane fails (agent errors or reports a RISKY blocker), retry it once
with a narrowed scope. After one retry, report the failure in the batch summary and continue
with the remaining lanes — no silent truncation.

Update status: `{"phase": "implement-batch", "step": 4, "activity": "implementers dispatched"}`.

### Step 5 — Test batch

Dispatch the **test-engineer agent** with: the batch's changed files, the implementer outputs
(including the `For test-engineer:` section from each agent's Output Format), and the plan task
description. The test-engineer writes tests for all tasks in the batch.

Update status: `{"phase": "test-batch", "step": 5, "activity": "test-engineer complete"}`.

### Step 6 — Run targeted tests

Select and run targeted tests for the batch's changed files using `/octo:test` selection logic:
map changed source paths to test files via explicit rules in `CLAUDE.md`, mirrored paths,
same-name matches, and import heuristics — in that order. Print the selection and rationale
before running. If a test fails, include the name, assertion, and diagnosis in the batch report.

Update status: `{"phase": "run-tests", "step": 6, "activity": "tests complete"}`.

### Step 7 — User checkpoint  ← STOP

Present a brief batch report:
- Tasks completed in this batch (task title, files changed)
- Test results (pass/fail counts)
- Any RISKY assumptions or open items from implementer/test-engineer outputs

For parallel batches, this checkpoint covers all tasks in the batch as a unit — supervision is between batches, not between tasks inside one batch.

Append any new [SAFE]/[RISKY] assumptions from implementer or test-engineer outputs to the plan file's ## Assumptions section — /octo:pr carries that section into the PR body, so nothing surfaced during execution is lost.

**STOP.** Wait for the user to approve before proceeding to the next batch. If the user
requests changes, dispatch the implementer for corrections, re-run tests, then re-present
this checkpoint.

Update status: `{"phase": "checkpoint", "step": 7, "activity": "awaiting user"}`.

### Step 8 — Conclude

After all batches are approved and complete, report:
- Total tasks implemented
- Aggregate list of files changed
- Any open items that could not be resolved

Update status: `{"phase": "conclude", "step": 8, "activity": "done"}`.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (`main`, `master`, `qa`, `staging`).
- Never use `--no-verify` or force-push.
- Fan-out cap: **10 parallel lanes**; retry once, then report the gap.
