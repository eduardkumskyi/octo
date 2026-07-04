---
name: handoff
description: "Write .claude/handoff.md so any future session can resume: current goal, done/remaining tasks, key decisions and assumptions, gotchas discovered, next step. The context-restore hook injects its head after compaction."
argument-hint: ""
---

## Progress Contract

Register these steps as a native task list at Step 1, before beginning. After each step, update
`.claude/octo/status.json` with `{"phase": <step-name>, "step": <N>, "activity": <short-string>}`.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Steps: (1) gather-state, (2) write-handoff.

## Workflow

### Step 1 — Gather state

Collect the information needed for each of the five sections:

- **Current goal** — what the session was trying to accomplish; include any scope constraints.
- **Done / remaining tasks** — tasks completed this session and tasks still open. Reference
  plan file path if one exists (`.claude/plans/` latest by name).
- **Key decisions and assumptions** — architectural choices, SAFE/RISKY assumptions surfaced,
  and the rationale behind each. Pull from the plan's `## Assumptions` section when available.
- **Gotchas discovered** — surprising findings, environmental quirks, or traps that are not
  obvious from the code or docs (e.g. field naming mismatches, hidden dependencies, deploy
  ordering constraints).
- **Next step** — the single most important action for the next session to take first.

Also note: current branch, any uncommitted changes, and the last commit SHA (`git rev-parse --short HEAD`).

Update status: `{"phase": "gather-state", "step": 1, "activity": "state gathered"}`.

### Step 2 — Write handoff  ← overwrites previous

Write `.claude/handoff.md` with exactly these five sections, in this order:

```
# Handoff

## Current goal
<one paragraph>

## Done / remaining
<bullet list: ✓ done items, ○ open items>

## Key decisions and assumptions
<bullet list with SAFE/RISKY tags where applicable>

## Gotchas
<bullet list — omit if empty>

## Next step
<one sentence — the single action to take first>
```

**Head constraint**: the first 30 lines of the file must be self-sufficient — they are what
the context-restore hook re-injects after compaction. Put the highest-value context (goal,
next step, and the most critical gotchas) within those 30 lines. Longer details can follow.
Budget the head: ## Current goal ≤ 3 lines, ## Next step ≤ 2 lines, most critical gotchas ≤ 5 lines — these three MUST sit inside the first 30 lines; everything else goes below the fold.

**Living pointer**: overwrite the previous `.claude/handoff.md` entirely. Git history is not
the archive — the file is a single pointer to the current resumption state, not a log.

After writing, print the first 30 lines so the user can verify they are self-sufficient.

Update status: `{"phase": "write-handoff", "step": 2, "activity": "handoff written"}`.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
