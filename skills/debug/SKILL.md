---
name: debug
description: "Systematic root-cause debugging: reproduce first (ideally as a failing test), rank hypotheses, investigate independent ones in parallel, falsify with evidence, fix the cause not the symptom, keep the repro as a regression test, record a lesson."
argument-hint: "<bug description>"
---

## Progress Contract

Register these steps as a native task list at Step 1, before beginning.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to in_progress/completed as you go — the checklist is the user's primary progress view.

Steps: (1) reproduce, (2) hypothesize, (3) falsify, (4) fix, (5) lesson.

**Hard rule: no fix without a confirmed root cause and a repro.**

## Workflow

### Step 1 — Reproduce

Construct a minimal reproduction case. Prefer a failing automated test; if a test is not
feasible, document the exact command or sequence that triggers the bug.

Print the repro: command or test name, observed output, expected output.

If reproduction fails — the bug cannot be triggered — stop and ask the user for more context.
Do not proceed to hypotheses without a confirmed repro.


### Step 2 — Hypothesize

List candidate root causes in ranked order (most likely first). For each hypothesis, state:
the mechanism, what evidence would confirm or refute it, and whether it can be investigated
independently.

Group independent hypotheses. Dispatch **one subagent per independent hypothesis in a single
message** — this MUST be a single message; serial investigation when parallel dispatch is
possible is a defect, not a style choice. Fan-out cap: 10 lanes. Each subagent receives the
repro, the hypothesis, and the relevant source paths.


### Step 3 — Falsify

Evaluate evidence returned by each subagent. Use instrumentation, log analysis, or `git bisect`
to distinguish surviving candidates from refuted ones.

Continue until exactly one hypothesis remains. If multiple hypotheses survive, dispatch another
round of targeted investigation (one subagent per surviving candidate) before proceeding.
Maximum 3 falsification rounds; if multiple hypotheses still survive, stop and present the surviving candidates with their evidence to the user rather than dispatching again.

Print the surviving root cause with the evidence chain that confirms it.


### Step 4 — Fix  ← STOP if no confirmed root cause and repro

Gate: if Step 3 did not end with exactly one surviving, evidence-backed hypothesis AND a repro from Step 1, stop and go back — do not dispatch a fix.

Dispatch the **implementer agent** with the confirmed root cause, the repro case, and the
source paths involved. The implementer fixes the root cause — not a downstream symptom.

The repro test (from Step 1) stays in the codebase as a **regression test**. If the repro was
a manual sequence rather than an automated test, dispatch the **test-engineer agent** to author
a regression test before the fix lands.

Verify the fix resolves the repro: re-run the regression test and confirm it passes.


### Step 5 — Record lesson and update brain  ← STOP if nothing to record

Write one lesson card at `.claude/octo/lessons/<kebab-slug>.md` capturing the root cause as a
reusable anti-pattern.

After writing the lesson card, update `.claude/octo/brain.md`: append any durable codebase knowledge learned from this debug session (a module's unexpected behavior, a danger zone, a control flow quirk). Brain sections: Architecture / Where things live / Conventions / Danger zones / Key flows. Cap ~150 lines, merge don't duplicate; create the file if absent. Slug = kebab-case of the `pattern` field. If a card with the same slug
exists, update its `date` and `## Example` section instead of duplicating.

```
---
pattern: <one-line anti-pattern description>
severity: low|medium|high  # CRITICAL→high
source: debug
date: YYYY-MM-DD
---
```

Body ≤ 25 lines, two required sections: `## Example` (file:line citation) and `## How to catch`
(concrete detection guidance).

**Cap — 50 cards per project** (`.claude/octo/lessons/`); **20 global** (`~/.claude/octo/lessons/`).
Before writing, count existing cards. If at cap, run an inline mini-retro: merge near-duplicates
and prune outgrown lessons, then add the new card. Never exceed the cap without pruning first.


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
