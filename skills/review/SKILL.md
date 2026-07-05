---
name: review
description: Multi-lens parallel review loop - four reviewer lenses fan out over the diff, findings are adversarially verified, confirmed ones fixed, and the loop repeats until a pass comes back clean (max 3 iterations). Confirmed findings become lesson cards.
argument-hint: "[--staged | --branch | --report-only | <paths>]"
---

## Progress Contract

Register these steps as a native task list at Step 1, before beginning.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.
Report loop progress as `iteration k/3` and `n/4 lenses done`.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to in_progress/completed as you go — the checklist is the user's primary progress view.

Steps: (1) resolve-diff, (2) review-fan-out, (3) adversarial-verify, (4) apply-fixes,
(5) write-lessons, (6) conclude.

## Arguments

- **`--staged`** — diff staged changes only (`git diff --cached`).
- **`--branch`** — commits on the current branch not yet on the resolved base. Base: `git symbolic-ref refs/remotes/origin/HEAD` (strip to branch name); if unset, `main` if it exists, else `master`. State the chosen base.
- **`--report-only`** — list confirmed findings; skip fixes. Runs exactly one pass (lenses + skeptics), writes lesson cards, then exits — no iterations.
- **`<paths>`** — restrict the diff to the listed paths. Mutually exclusive with `--staged` and `--branch`; if combined, error and ask the user to choose.
- **default (no flags)** — working tree and staged changes combined (`git diff HEAD`). Covers uncommitted work (pre-commit review); this differs intentionally from `/octo:test`, which targets committed code. Use `--branch` to review committed work.

## Workflow

### Step 1 — Resolve diff

Compute the diff using the scoping rules from Arguments. Print which scope was chosen and how
many files are in the diff.

If the diff is **empty**: report "no changes detected" and exit. Do not start the review loop.


### Step 2 — Review fan-out  ← one pass per iteration

Dispatch **four reviewer subagents in a single message** (one per lens: `bugs`, `security`,
`performance`, `simplicity`). Pass each subagent the diff and the list of changed paths — the
reviewer uses paths for lesson relevance ranking. Do not duplicate lens checklists, rubric, or
output format here; the reviewer agent owns those (see `agents/reviewer.md`).

Report `iteration k/3` at the start of each pass. Report `n/4 lenses done` as each subagent
returns.


### Step 3 — Adversarial verification

Dispatch **all skeptics for this pass's findings in one message** (one skeptic per finding,
concurrently) — sequential skeptic dispatch is a defect, not a style choice. Each skeptic
receives: (a) the finding verbatim (file:line + excerpt) and (b) the surrounding diff hunk or
file section. The skeptic must return exactly `REFUTED: <reason>` or `UPHELD: <reason>`.
**Uncertain ⇒ UPHELD** — the skeptic exists to kill clear false positives, not to shed real
bugs. Only REFUTED findings are dropped; UPHELD findings carry forward.

Model scales with stakes — `haiku` for LOW or MEDIUM severity; `inherit` for HIGH or CRITICAL
(a cheap skeptic must never be the reason a real security bug gets dismissed).

Finding severity comes from the reviewer agent's rubric (CRITICAL/HIGH/MEDIUM/LOW).


### Step 4 — Apply fixes  ← STOP if --report-only

If `--report-only`: print confirmed findings with severity and location; skip the implementer
dispatch. Proceed to Step 5 then exit — do not return to Step 2.

Otherwise, dispatch the **implementer agent** with the full list of confirmed findings. The
implementer applies fixes to the working tree. After fixes, recompute the diff on the updated
state.


### Step 5 — Write lesson cards

If another iteration will follow (Step 6 loops back), skip this step now — cards are written only on the final pass (or the single --report-only pass).

Write cards **once per run, at exit**, from the final confirmed-findings set — not per
iteration. For every confirmed finding, create `.claude/octo/lessons/<kebab-slug>.md`:

```
---
pattern: <one-line anti-pattern description>
severity: low|medium|high  # CRITICAL→high
source: review
date: YYYY-MM-DD
---
```

Slug = kebab-case of the card's one-line `pattern`. If a card with the same slug already
exists, update its `date` and `## Example` section instead of creating a duplicate.

Body ≤ 25 lines, two required sections:

- `## Example` — `file:line` citation from the finding
- `## How to catch` — concrete detection guidance

**Cap — 50 cards per project; 20 in the global store (`~/.claude/octo/lessons/`).** Before writing, count existing cards. If already at 50, run an
inline mini-retro: identify near-duplicates and outgrown lessons, merge or prune them, then add
the new card. Never exceed 50 without pruning first.


### Step 6 — Iterate or conclude

If `--report-only` was set: exit — Step 4 already directed this path.

If the current pass has **zero confirmed findings**: report the diff is clean and exit.

If this was **iteration 3**: exit. Report any residual confirmed findings honestly — file,
severity, and a one-line summary for each — so the next pass or human reviewer knows what
remains. Present the final output as a findings table with columns: Severity | File | Finding | Fixed?

Otherwise increment the iteration counter. Recompute the diff for the next pass: for
**default/`--staged`**, use the same scope as originally defined; for **`--branch`**, use
`git diff <resolved-base>` (working tree against base — captures both the branch's commits and
uncommitted fixes applied in Step 4). Return to Step 2 with the recomputed diff.


---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Parallel-first: dispatches that do not consume each other's output MUST go in a single
  message. Dispatching sequentially what could run concurrently is a defect, not a style
  choice. Cap ≈10 concurrent lanes; more work than lanes → batch waves.
