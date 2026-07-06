---
name: retro
description: "Session post-mortem: mine the conversation for user corrections, confirmed review findings, and debug root causes; distill them into lesson cards; merge duplicates and prune stale ones."
argument-hint: ""
---

## Progress Contract

Register these steps as a native task list at Step 1, before beginning.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Steps: (1) mine-session, (2) write-cards, (3) curate.

## Workflow

### Step 1 — Mine session

Dispatch **three subagents in one message** — one per signal type — to mine the conversation
history concurrently. Sequential mining of independent signal types is a defect:

- **(a) User corrections** — any place the user rejected an output, flagged a mistake, or
  corrected an assumption. Extract the erroneous pattern and the correct approach.
- **(b) Confirmed review findings** — findings that survived adversarial verification in any
  `/octo:review` pass this session. Use the upheld severity and file:line citation.
- **(c) Debug root causes** — root causes confirmed in any `/octo:debug` run this session,
  with the evidence chain that confirmed them.

Collect all three subagent results and merge them before proceeding. For each signal, draft a
candidate lesson: one-line `pattern`, severity, and a brief note on how to detect or prevent
recurrence. Deduplicate candidates across all three sets.

Print a summary: `"N candidate lessons found (a: X, b: Y, c: Z)."` If zero, exit — no cards
to write, no curation needed.


### Step 2 — Write cards

For each candidate lesson, write a card at `.claude/octo/lessons/<kebab-slug>.md`.
Slug = kebab-case of the `pattern` field. If a card with the same slug already exists,
update its `date` and `## Example` section instead of creating a duplicate.

```
---
pattern: <one-line anti-pattern description>
severity: low|medium|high  # CRITICAL→high
source: retro
date: YYYY-MM-DD
---
```

Body ≤ 25 lines, two required sections: `## Example` (file:line citation or conversation
reference — deliberate extension of the card contract for user-correction lessons, which have no file:line) and `## How to catch` (concrete detection guidance).

**Cap — 50 cards per project** (`.claude/octo/lessons/`); **20 global** (`~/.claude/octo/lessons/`).
Write to `~/.claude/octo/lessons/` only when the lesson is about YOUR habits across projects (e.g. 'I always forget timezone handling'), not about this codebase.
Before writing each card, count existing cards. If at cap, run the inline mini-retro in
Step 3 first, then return here to write.


### Step 3 — Curate

Read all cards in `.claude/octo/lessons/`. Perform curator duties:

- **Merge near-duplicates** — cards whose `pattern` fields describe the same anti-pattern.
  Keep the card with the richer `## Example`; absorb the other's date if it is newer.
- **Prune outgrown lessons** — cards that described a temporary workaround, a now-fixed
  framework bug, or a pattern the codebase has since eliminated. Delete them.
  Deletion bounds: never delete a card younger than 14 days or created in this session;
  declare a card 'outgrown' only with evidence (the pattern no longer exists in the code —
  name what you checked); list every deleted card with its reason in the retro report —
  deletions must be visible, never silent. When enforcing caps, prefer merging over deleting,
  and among deletion candidates pick lowest-severity first, breaking ties by oldest.
- **Enforce caps** — after merging and pruning, confirm project ≤ 50, global ≤ 20. If still
  over cap, prune the lowest-severity or oldest cards until within limits.
- **Enforce card length** — any card body exceeding 25 lines is trimmed to the most essential
  content.

Print a curation summary: cards added, merged, pruned, and final count.


---

## When to run

Run `/octo:retro` at the end of any significant session (a session that produced confirmed
review findings, debug root causes, or user corrections) or immediately after a production
escape, while the context is still available.

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
