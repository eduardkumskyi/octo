---
name: build
description: "Autonomous task mode: plan with an up-front assumption gate, implement with tests in parallel where file-disjoint, run targeted tests until green (max 5 cycles), review until clean (max 3 iterations), full-suite gate per project weight, then offer a PR. One command, no mid-run questions after the gate."
argument-hint: "<task description>"
---

## Progress Contract

Register these steps as a native task list at the start of Step 1, before any exploration.
After each step, update `.claude/octo/status.json` with
`{"phase": <step-name>, "step": <N>, "activity": <short-string>}`.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Steps: (1) read-context, (2) plan-gate, (3) implement, (4) test-fix-loop,
(5) review, (6) final-gate.

**State-write gate**: a step has not STARTED until its `state.json` overwrite and
`events.jsonl` entry are written. Write state FIRST, then do the step's work — never the
reverse. A growing "updated Xm ago" on the task checklist or wave means you are violating this contract.

## Arguments

- **`<task description>`** — what to build. Required; if omitted, ask once then proceed.

## Workflow

### Step 1 — Read context and initialize run state

Read the host project's `CLAUDE.md`. If absent or missing a needed section:
- State what is missing explicitly.
- Offer to scaffold a minimal `CLAUDE.md` and wait for the user's answer.
- Detect conventions from repo artifacts (`pyproject.toml`, `Makefile`, `package.json`,
  CI config). Label every inferred convention `[DETECTED]`.

If `.claude/octo/run/state.json` already exists with `updated` less than 15 minutes old,
another run may be active in this project — raise this at the Step-2 gate as a RISKY item
and get explicit confirmation before overwriting.

Initialize run state:
- Overwrite `.claude/octo/run/state.json`:
  `{"mode": "build", "mission": "<task>", "phase": "read-context", "step": 1, "updated": "<ISO>"}`.
- Append to `.claude/octo/run/events.jsonl`:
  `{"ts": "<ISO>", "type": "start", "mode": "build", "mission": "<task>"}`.

Create the native task list for this session (all six steps). This is the single source of
truth for human-visible progress.

Update status: `{"phase": "read-context", "step": 1, "activity": "context read, run state initialized"}`.

### Step 2 — Plan and assumption gate  ← STOP

Run the /octo:plan workflow (parallel exploration, architect agent, plan file saved to
`.claude/plans/`). Do not duplicate plan internals here; /octo:plan owns them.

**This is the last user contact for this run.** Scan `## Assumptions` for any item marked
`RISKY` where the consequence is also hard to reverse (schema migrations, public API removals,
irreversible data transforms). If any such item exists, surface each as a clear question and
wait for answers before saving the plan.

After the gate clears: the run is unattended. Any new ambiguity discovered later is resolved
by choosing the **most reversible option** and recording it in the plan's `## Assumptions` —
never silently, and never by asking the user again.

Append to `.claude/octo/run/events.jsonl`:
`{"ts": "<ISO>", "type": "step", "phase": "plan-gate", "activity": "gate cleared"}`.
Update status: `{"phase": "plan-gate", "step": 2, "activity": "plan saved, gate cleared"}`.

### Step 3 — Implement with tests

**First action of this step**: overwrite `state.json` with `phase` set to `"implementing"` and
the dispatched lanes — do this before any implementation work begins.

Unattended rule: any new ambiguity → choose the most reversible option and append it as `[SAFE]`/`[RISKY]` to the plan's `## Assumptions` — never silently, never by asking.

This step is fully unattended — **no user checkpoints between tasks** (that is /octo:implement's
job; /octo:build skips its Step 7 checkpoint intentionally).

For each plan task, dispatch one **implementer subagent** paired with one **test-engineer
subagent**. File-disjoint tasks run in parallel — dispatch all lanes for a batch in **one
message** (fan-out cap: 10 lanes). Tasks whose affected files overlap with an in-progress
batch are deferred until that batch completes.

Note: unlike /octo:implement (N implementers, then one test-engineer for the batch), build pairs an implementer and test-engineer per task — pairs run concurrently and cannot see sibling tasks' changes; the Step 4 test run is where cross-task breakage surfaces.

Pass each subagent: the plan, its specific task, the affected files, and any relevant lessons
from `.claude/octo/lessons/*.md`.

**Failure rule**: if a lane errors or reports a RISKY blocker, retry it once with a narrowed
scope. After one retry, record the failure in the batch summary and continue remaining lanes —
no silent truncation.

At dispatch time, write each lane to `.claude/octo/run/state.json` (agent, task, started=now).
After each completed batch, clear and rewrite lanes in `.claude/octo/run/state.json` and
append to `.claude/octo/run/events.jsonl`:
`{"ts": "<ISO>", "type": "batch", "tasks": ["<task-id>", ...], "status": "done|partial"}`.

Update status: `{"phase": "implement", "step": 3, "activity": "all batches complete"}`.

### Step 4 — Targeted test loop (max 5 cycles)

Unattended rule: any new ambiguity → choose the most reversible option and append it as `[SAFE]`/`[RISKY]` to the plan's `## Assumptions` — never silently, never by asking.

Run targeted tests for all changed files using /octo:test's selection logic: explicit rules in
`CLAUDE.md` → mirrored paths → same-name matches → import heuristics, in that order. Always
print the selection and rationale before each run.

If tests fail, dispatch the **implementer agent** to fix failures and re-run. Repeat for at
most **5 cycles total**. If tests are still red after cycle 5: stop immediately, report every
failure with name, assertion, and diagnosis — **never claim done over red**. Run
`bash scripts/notify.sh "octo build" "blocked: tests red after 5 cycles"`, write final
`.claude/octo/run/state.json`, append
`{"ts": "<ISO>", "type": "blocked", "reason": "tests red after 5 cycles"}`
to `.claude/octo/run/events.jsonl`, and exit.

On success, append to `.claude/octo/run/events.jsonl`:
`{"ts": "<ISO>", "type": "step", "phase": "test-fix-loop", "activity": "green"}`.
Update status: `{"phase": "test-fix-loop", "step": 4, "activity": "tests green"}`.

### Step 5 — Review

Unattended rule: any new ambiguity → choose the most reversible option and append it as `[SAFE]`/`[RISKY]` to the plan's `## Assumptions` — never silently, never by asking.

Run the /octo:review loop; invoke it with the explicit paths of all files the plan's tasks touched (from the plan's per-task file lists); if Step 3 committed work along the way, use `--branch` instead so committed changes are included. The review skill's own 3-iteration cap applies; do not re-implement it here.

After each review pass, append one event per confirmed finding:
`{"ts":"<ISO>","type":"finding","iteration":<k>,"severity":"<sev>","summary":"<one line>"}`.
(studio inherits this via composition — add no duplicate text there.)

If review exits at cap with residual confirmed findings: HIGH/CRITICAL residuals → treat as
blocked (run `bash scripts/notify.sh "octo build" "blocked: unresolved HIGH/CRITICAL findings"`,
write `.claude/octo/run/state.json`, append
`{"type": "blocked", "reason": "unresolved HIGH/CRITICAL findings"}`
event to `.claude/octo/run/events.jsonl`, stop and report — never proceed over unresolved
HIGH/CRITICAL). LOW/MEDIUM residuals → proceed to Step 6 and list them prominently in the
final report.

Append to `.claude/octo/run/events.jsonl`:
`{"ts": "<ISO>", "type": "step", "phase": "review", "activity": "review complete"}`.
Update status: `{"phase": "review", "step": 5, "activity": "review clean"}`.

### Step 6 — Final gate and hand-off

Unattended rule: any new ambiguity → choose the most reversible option and append it as `[SAFE]`/`[RISKY]` to the plan's `## Assumptions` — never silently, never by asking.

Run the full test suite plus lint. Exception: if `CLAUDE.md` declares `weight: heavy`, run
targeted tests only and state that explicitly — the gate is never silently skipped.

On gate failure: run `bash scripts/notify.sh "octo build" "blocked: final gate failed"`,
write final `.claude/octo/run/state.json`, append
`{"ts": "<ISO>", "type": "blocked", "reason": "final gate failed"}`
to `.claude/octo/run/events.jsonl`, report all failures, and exit.

On gate success:
1. Run `bash scripts/notify.sh "octo build" "done: <mission>"`.
2. **Offer** to run `/octo:pr` — do **not** auto-create the PR.

Append to `.claude/octo/run/events.jsonl`:
`{"ts": "<ISO>", "type": "complete", "mission": "<task>"}`.
Update status: `{"phase": "final-gate", "step": 6, "activity": "done"}`.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Fan-out cap: **10 parallel lanes**; retry once, then report the gap.
- On failure at any step: `bash scripts/notify.sh "octo build" "blocked: <reason>"`,
  overwrite `.claude/octo/run/state.json` with the final phase, append
  `{"ts": "<ISO>", "type": "blocked", "reason": "<reason>"}` to `.claude/octo/run/events.jsonl`,
  and report.
