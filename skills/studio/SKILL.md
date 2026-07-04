---
name: studio
description: "Client mode: one contract sign-off, then the agents run like a studio until delivery - consilium panels decide instead of the user, milestones are atomic and verified, all state lives on disk, and any session can resume the run. Zero questions between sign-off and delivery."
argument-hint: "<mission> | --resume"
---

## Progress Contract

Register these phases as a native task list at the start of Phase 1, before any interview.
After each phase transition, update `.claude/octo/status.json` with
`{"phase": <phase-name>, "step": <N>, "activity": <short-string>}`.
Report progress as "N phases remaining, milestone M of K" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <milestone-id> <n>/<total> — <step>`; update each to in_progress/completed as you go — the checklist is the user's primary progress view.

Phases: (1) contract, (2) consilium-setup, (3) milestone-loop, (4) resume, (5) delivery.

**State-write gate**: a step has not STARTED until its `state.json` overwrite and
`events.jsonl` entry are written. Write state FIRST, then do the step's work — never the
reverse. A growing "updated Xm ago" on the task checklist or wave means you are violating this contract.

Relationship note: build = task / hours / user nearby; studio = mission / days / user absent.
Accepted interpretation: supervision granularity inside the inner loop is per-batch.

## Arguments

- **`<mission>`** — what to build; required on a fresh run. If omitted, ask once, then proceed.
- **`--resume`** — re-attach to an interrupted studio run; see Phase 4.

## Phase 1 — Contract  ← STOP

This is the only moment the studio contacts the client for decisions. Use AskUserQuestion for every enumerable choice in the interview (control scheme, scope options, limits); free-text prose only for genuinely open fields like the mission statement. Conduct a deep interview covering six topics, in this order:

1. **Mission** — what outcome must exist in the world when the run finishes?
2. **Acceptance Criteria** — ask "done means…" for each deliverable; push for observable, testable answers.
3. **Preferences** — tone, technology choices, naming conventions, any taste worth preserving.
4. **Constraints** — hard limits: budget, runtime, forbidden dependencies, compliance rules.
5. **Delegation** — record this clause verbatim: *"All decisions not listed above are the studio's to make."*
6. **Limits** — optional: time box, cost ceiling, maximum milestone count.

Write `.claude/octo/run/contract.md` with six top-level sections matching those headings:
Mission / Acceptance Criteria / Preferences / Constraints / Delegation / Limits.

Present the draft to the client. On acceptance, the run is sealed:

- **Zero further questions** — any ambiguity that arises is resolved by the consilium (Phase 2), never by the client.
- **One exception**: corrupt or missing state on `--resume` halts the run and reports to the client before any work begins (Phase 4).

Initialize run state:

- Write `.claude/octo/run/state.json`:
  `{"mode":"studio","mission":"<mission>","phase":"contract","milestones":[],"updated":"<ISO>"}`.
- Append to `.claude/octo/run/events.jsonl`:
  `{"ts":"<ISO>","type":"start","mode":"studio","mission":"<mission>"}`.

Update status: `{"phase":"contract","step":1,"activity":"contract accepted, run sealed"}`.

## Phase 2 — Consilium

Whenever execution would otherwise pause for a user decision — a design fork, a missing requirement,
a scope question, a dependency choice — convene a consilium panel instead.

Dispatch three seats **in one message** (parallel tool-use blocks):

| Seat | Mandate |
|------|---------|
| **Client advocate** | Argues from `contract.md` — what did the client actually ask for? |
| **Pragmatist** | Proposes the simplest option that ships and is safe to reverse. |
| **Risk** | Identifies what breaks later if this choice is wrong. |

After all three seats report, dispatch the **architect** as judge. Seat votes are advisory;
the architect rules on the merits of the arguments, not by majority count. The ruling is one of:
`ACCEPT`, `ACCEPT WITH CHANGES`, or `REJECT`. For anything other than a plain `ACCEPT`, the
architect must list the specific conditions or blockers.

Append every decision to `.claude/octo/run/decisions.md`:

```
## D<n> — <question>

Seats:
- Client advocate: <one-line argument>
- Pragmatist: <one-line argument>
- Risk: <one-line argument>

Ruling: ACCEPT | ACCEPT WITH CHANGES | REJECT
Rationale: <architect's reasoning>
Date: <ISO date>
```

Append to `.claude/octo/run/events.jsonl`:
`{"ts":"<ISO>","type":"decision","id":"D<n>","question":"<question>","ruling":"<ruling>"}`.

Initialize `.claude/octo/run/decisions.md` (empty header) before the first milestone starts
so the file is always present and appendable.

Update status: `{"phase":"consilium-setup","step":2,"activity":"decisions log initialized"}`.

## Phase 3 — Milestone loop

**Decompose** the mission into demoable milestones — each must produce a runnable, observable
artifact that the verifier can exercise. Write `.claude/octo/run/board.md` (a markdown status
table: `| ID | Title | Status |`) and update `.claude/octo/run/state.json` with the full
milestone list, each at status `PENDING`.

**Sync rule**: `board.md` and `state.json` must reflect the same status for every milestone at
every transition. Write order: state.json first, then board.md. On resume, if the two disagree,
state.json is authoritative — rewrite board.md from it and log a journal event. If state.json is
missing while board.md exists, that is corrupt state: halt and report.

For each milestone, in sequence:

### 3a — Start the milestone

Set the milestone to `IN_PROGRESS` in both `board.md` and `.claude/octo/run/state.json`. Append
to `.claude/octo/run/events.jsonl`:
`{"ts":"<ISO>","type":"milestone","id":"<id>","title":"<title>","status":"IN_PROGRESS"}`.

### 3b — Build inner loop

Run `/octo:build` Steps 3–5 for this milestone's scope — implement with paired tests, targeted
test loop (max 5 cycles), and review until clean (max 3 iterations). The unattended rule,
residuals policy, and terminal blocked-event protocol from the build skill apply in full here;
do not restate that detail, apply it; and suppress build's own `octo build` notify and blocked
event on that path — studio emits its own notifications and events with the `octo studio` label.

Any new ambiguity during this loop is resolved by the most reversible option (recorded as an
`{"type": "assumption", "label": "SAFE|RISKY", ...}` event in `.claude/octo/run/events.jsonl`),
or escalated to the consilium if the consequence is hard to reverse — never by asking the client.
RISKY + hard-to-reverse goes to consilium instead. All recorded assumptions surface in the
delivery report.

At dispatch time, write each lane to `.claude/octo/run/state.json` (agent, task, started=now).
After each completed batch, clear and rewrite lanes in `.claude/octo/run/state.json` and
append to `.claude/octo/run/events.jsonl`:
`{"ts":"<ISO>","type":"batch","milestone":"<id>","tasks":["<task-id>",...],"status":"done|partial"}`.

If the inner loop exits blocked (tests red after 5 cycles, or HIGH/CRITICAL review residuals
unresolved): proceed to Step 3c with a `FAIL` signal rather than halting the entire run.
Inner-loop blocked exits emit no notify and no blocked event — they become the FAIL signal to 3c;
only run-terminal blocks use the Shared Conventions notify.

### 3c — Verify, re-plan, or park

Dispatch the **verifier** against the milestone's demo criteria. On `PASS`:

1. `git commit` all milestone work: `type(scope): <milestone title>`.
2. Set status `VERIFIED` in both `board.md` and `.claude/octo/run/state.json`.
3. `bash scripts/notify.sh "octo studio" "milestone verified: <title>"`.
4. Append: `{"ts":"<ISO>","type":"milestone","id":"<id>","title":"<title>","status":"VERIFIED"}` to `.claude/octo/run/events.jsonl`.
5. Update status.json and advance to the next milestone.

On `FAIL`, `PARTIAL`, or a blocked inner loop: convene the consilium to decide whether and how
to re-plan. If the ruling is `ACCEPT` or `ACCEPT WITH CHANGES`, apply the re-plan and restart
from Step 3b — **maximum 2 re-plans per milestone total**. After 2 failed re-plans, or on a
consilium `REJECT`:

1. Set status `PARKED` in both `board.md` and `.claude/octo/run/state.json`.
2. Append a decisions.md entry (D\<n\>) capturing the question, ruling, and reason for parking.
3. `bash scripts/notify.sh "octo studio" "milestone parked: <title>"`.
4. Append: `{"ts":"<ISO>","type":"milestone","id":"<id>","title":"<title>","status":"PARKED"}` to `.claude/octo/run/events.jsonl`.
5. Continue to the next milestone — parked milestones appear in the delivery report.

Update status.json after each milestone: `{"phase":"milestone-loop","step":3,"activity":"milestone <id> <VERIFIED|PARKED>"}`.

## Phase 4 — Resume & atomicity

When invoked with `--resume`:

1. Read `.claude/octo/run/contract.md`, `.claude/octo/run/board.md`, `.claude/octo/run/decisions.md`, and `.claude/octo/run/state.json`.
2. If any file is **missing or malformed**: halt immediately. Report exactly which file failed
   and why — this is the one allowed post-contract contact with the client. Do no work until the
   client resolves the state corruption.
3. Never re-interview. The contract file is the sole source of mission truth.
4. Find the first milestone with status `IN_PROGRESS`. Revert any uncommitted changes in that
   milestone's scope to the last git commit, then restart from Step 3b. Never resume from
   half-written files.
5. If no `IN_PROGRESS` milestone exists, continue from the first `PENDING` milestone.
6. If no milestone is `IN_PROGRESS` or `PENDING` and no delivery report exists, proceed directly
   to Phase 5 (delivery).

Append to `.claude/octo/run/events.jsonl`:
`{"ts":"<ISO>","type":"resume","last_phase":"<phase from state.json>"}`.

Update status: `{"phase":"resume","step":4,"activity":"state restored, continuing"}`.

## Phase 5 — Delivery

When all milestones are `VERIFIED` or `PARKED`:

If ALL milestones are `PARKED`, skip the verifier and go straight to the INCOMPLETE report (the INCOMPLETE path's notify applies here too).

1. Dispatch the **verifier** against the contract's Acceptance Criteria in full (not per-milestone).
2. On acceptance pass, produce the delivery report. Begin with an acceptance-criteria checklist (✅/❌ per criterion from the contract). Then include the following bullet sections:
   - **What was built** — one paragraph per VERIFIED milestone, linking to the git commit.
   - **How to run it** — exact commands from the project's CLAUDE.md or detected conventions.
   - **Decision minutes summary** — each D\<n\> entry condensed to one line.
   - **Parked items** — title, reason, and recommended next step for each.
   - **Recorded assumptions** — every `type: assumption` event from events.jsonl, with labels.
   - **Known limitations** — anything discovered during the run that falls outside contract scope,
     plus any LOW/MEDIUM review residuals carried from milestone inner loops.
   Then: `bash scripts/notify.sh "octo studio" "delivery ready: <mission>"`;
   append `{"ts":"<ISO>","type":"delivery","mission":"<mission>","milestones_verified":<N>,"milestones_parked":<N>}`
   to `.claude/octo/run/events.jsonl`.

   On acceptance fail: produce the same delivery report but headline it **INCOMPLETE** — what was
   built, which acceptance criteria are unmet and why, parked milestones, recommended next runs.
   `bash scripts/notify.sh "octo studio" "delivery incomplete: <mission>"`. Never present an
   incomplete run as delivered.

3. Update status: `{"phase":"delivery","step":5,"activity":"done"}`.

The client reviews the delivery report and either accepts or files change requests.
Change requests become a **new, smaller studio run** — the current run is closed as-is.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Fan-out cap: **10 parallel lanes**; retry a lane once on error, then report the gap.
- On any blocked event: `bash scripts/notify.sh "octo studio" "blocked: <reason>"`,
  overwrite `.claude/octo/run/state.json` with the current phase, append
  `{"ts":"<ISO>","type":"blocked","reason":"<reason>"}` to `.claude/octo/run/events.jsonl`, and report.
