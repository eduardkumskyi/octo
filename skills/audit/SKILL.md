---
name: audit
description: "PR-style pre-merge audit: exhaustive, skeptical, read-only review of the current branch against a base chosen from a question card, across companion repos confirmed by active-work detection. Reviews like a senior engineer trying to block a risky merge — severity-graded findings with concrete failure modes, cross-repo compatibility, must-fix vs safe-to-defer; then optionally select findings to fix."
argument-hint: "[base-branch] [--repos <path>...]"
---

## Progress Contract

Register these steps as a native task list at Step 1, before any resolution work.
Report progress as "N steps remaining" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to
in_progress/completed as you go — the checklist is the user's primary progress view.

Steps: (1) resolve-matrix, (2) per-repo-review, (3) cross-repo-lens, (4) skeptic-verify,
(5) report, (6) fix-selection.

## Arguments

- **`[base-branch]`** — explicit base branch to diff against. If omitted, resolved
  via a question card (see Step 1). Any positional argument that does not start with `--` is
  treated as the base branch.
- **`--repos <path>...`** — one or more paths to companion repos to include in the audit.
  Overrides CLAUDE.md companion-repo discovery and auto-detection entirely.

## Workflow

### Step 1 — Resolve audit matrix

**Base branch resolution** (first match wins; always announce the chosen base and why):

1. Explicit argument — a positional arg provided by the user.
2. `review base:` or `audit base:` directive in the host project's `CLAUDE.md` — scan for
   either key.
3. Question card — list all branches that exist on origin from the candidate set
   `[staging, qa, develop, main, master]` via `git ls-remote --heads origin`; collect every
   hit. Then present **one AskUserQuestion**: "Compare against which base?" with those
   branches as options. Mark the recommended branch "(Recommended)" and place it first:
   prefer `staging` if present, otherwise the repo default
   (`git symbolic-ref refs/remotes/origin/HEAD`, strip to branch name; if unset, the first
   hit from the candidate set). **Never silently pick a base; never ask the user to type a
   branch name.**

After resolving the base, fetch it: `git fetch origin <base>`.

The chosen base is applied to companions too when it exists on their origin; otherwise each
companion falls back to its own CLAUDE.md `review base:`/`audit base:` setting or its own
question-card resolution (announce per repo which base was used and why).

**Companion repo candidates** (first match wins):

1. `--repos` arguments — use exactly the listed paths.
2. `companion repos:` line in the host `CLAUDE.md` — parse the paths from that line.
3. Sibling directories — list directories sharing the same parent as the current repo that
   contain `.git`.

**Active-work filter** — from the candidate list, a repo qualifies as an active companion
when **both** conditions hold (evaluated inside the companion's directory):
- Its currently checked-out branch is **not** its default branch
  (`git symbolic-ref refs/remotes/origin/HEAD`; if unset, `main` / `master`).
- It is ahead of the resolved base: `git rev-list --count <base>..HEAD` > 0.

Announce each sibling that is evaluated, whether it qualifies, and the reason (e.g.,
"on default branch", "0 commits ahead of staging", "no `.git`").

**Companion confirmation** — if one or more active companions are detected, present **one
multiSelect AskUserQuestion** before running any analysis:

- Each option = `"<repo-name>: <branch> vs <base> (+N commits)"` where N comes from
  `git rev-list --count <base>..HEAD`.
- All detected active candidates are pre-selected as included.
- State in the question preamble that the current (host) repo is always audited; the
  question covers only the companions.
- If no active candidates are found, skip the question and note
  "no companion repos with active work detected".

**Audit matrix** — after confirmation, print a table: Repo | Branch | Base — covering the
host repo and every confirmed companion. This is the contract for the rest of the run.

Register the 🐙 task checklist now.


### Step 2 — Per-repo review fan-out

For each repository in the audit matrix, dispatch **four reviewer subagents in a single
message** (one per lens: `bugs`, `security`, `performance`, `simplicity`). All repos can
fan out concurrently — dispatch all lanes for all repos in **one message** where possible
(fan-out cap: 10 lanes total; if the matrix would exceed the cap, batch by repo).

Pass each subagent:
- The diff for that repo: `git diff <resolved-base>...<current-branch>` (three-dot,
  branch-level diff) run inside that repo's directory.
- The list of changed files.
- An **audit-specific brief** beyond the standard lens checklist. The brief must cover:
  likely regressions, broken edge cases, behavior changes that callers won't expect,
  missing input validations, unsafe assumptions in control flow, dead code, duplicated
  logic, weak or missing typing, poor or absent error handling, missing loading/error
  states in UI, authentication and authorization gaps, migration risks (schema, data,
  config), config/env inconsistencies between environments, missing test cases for changed
  paths, and "technically correct but likely to cause problems later."

Report `n/4 lenses done` as each subagent returns per repo.


### Step 3 — Cross-repo integration lens

**Skip this step entirely if the audit matrix has only one repository.** Mark the task
complete and continue to Step 4.

When two or more repos are present, dispatch **one dedicated integration-reviewer subagent**
fed the diff summaries from all repos. The integration brief must cover:

- API contract alignment: do endpoint signatures, response shapes, and error codes still
  match across repos?
- Schema and serializer alignment: are model changes backward-compatible with consumers?
- Event and message shapes: do publishers and subscribers still agree on field names, types,
  and required vs optional fields?
- Environment and config consistency: are new env vars declared and consumed symmetrically?
- Deploy-order risks: would deploying repos in any plausible order (backend before frontend,
  agents before backend, etc.) cause a window of breakage?


### Step 4 — Skeptic verification pass

Follow the exact same skeptic protocol as `/octo:review` Step 3 — reference it; do not
restate it here. Apply it to every finding collected from Steps 2 and 3:

- Dispatch **all skeptics in one message** (one per finding, concurrently) — sequential
  skeptic dispatch is a defect. Each skeptic receives the finding verbatim and the
  surrounding diff hunk or file section.
- The skeptic returns `REFUTED: <reason>` or `UPHELD: <reason>`. Uncertain ⇒ UPHELD.
- Only REFUTED findings are dropped; UPHELD findings carry forward to the report.
- Model scales with stakes: `haiku` for LOW/MEDIUM; `inherit` for HIGH/CRITICAL.


### Step 5 — Report

Produce the audit report per the **Report Contract** below.

Read-only through the report. Nothing is modified unless you select fixes at the final step; pushes are never automatic.
Confirmed HIGH/CRITICAL findings become lesson-card candidates — follow the same card
contract as `/octo:review` Step 5 (write `.claude/octo/lessons/<kebab-slug>.md`; same
50-card cap, same slug/body rules). Do not write cards for MEDIUM/LOW findings unless they
reveal a recurring anti-pattern already present in the lessons store.


---

## Report Contract

This format is binding. Review it like a senior engineer trying to block a risky merge.

**Chat output rule**: in chat, present only the per-repo executive digest — a severity count table (CRITICAL / HIGH / MEDIUM / LOW) plus the must-fix list (finding title + file path, one line each) — and the cross-repo compatibility one-liner when applicable. Write the full report (all findings with evidence, failure modes, fix recommendations, regressions, missing tests) to `.claude/octo/reports/YYYY-MM-DD-audit-<slug>.md`; share the file path in chat.

### Per-repository section (one section per repo in the matrix)

**Executive summary** — two to five sentences: what changed, how risky it looks, net
assessment (safe to merge / merge with fixes / block).

**Findings** — grouped by severity in descending order: CRITICAL → HIGH → MEDIUM → LOW.
For each finding:

- **Title** — one line, concrete.
- **Classification** — one of: `confirmed issue` | `likely risk` | `code smell`.
- **Why it's a problem** — the failure mode, not a restatement of the code.
- **Location** — exact file(s), function(s), or area(s); prefer `file:line` citations.
- **How it fails in practice** — a concrete scenario: what input or condition triggers it,
  what breaks, what the user or downstream system observes.
- **Recommended fix** — specific and actionable. No vague advice without a concrete
  failure mode.

**Regressions and merge risks** — explicit list of behavior changes that may break callers,
downstream integrations, or existing tests. Include migration hazards if any.

**Missing tests worth adding** — list test cases that would catch the confirmed findings or
close the most dangerous untested paths. Omit if none are warranted.

### After all per-repository sections

**Cross-repo compatibility** — present only when the matrix had >1 repo; omits this section
entirely for single-repo audits. Summarize the integration-lens findings with the same
severity/location/failure-mode structure.

**Must fix before merge** — a numbered shortlist of findings that are blocking. No items
without a severity and a one-line failure mode.

**Safe to defer** — a numbered shortlist of confirmed findings that are real but non-blocking,
with a brief rationale for each deferral.

### Rules

- No vague advice without a concrete failure mode.
- No diff summarization — describe impact, not content.
- Prefer grounded `file:line` findings over area-level observations.
- Make reasonable assumptions rather than stopping for minor ambiguities; state any
  assumption made.
- Do not omit findings because they are uncomfortable — the audit exists to surface them.

---

### Step 6 — Post-report fix selection

1. Ask via AskUserQuestion (single question): "What should I fix now?" with options:
   - "All must-fix items (Recommended)"
   - "Must-fix + safe-to-defer"
   - "Let me pick individually"
   - "Nothing — report only"

2. If "Let me pick individually": present the confirmed findings as multiSelect AskUserQuestion(s), batched up to 4 options per question, up to 4 questions per call (use additional calls if more findings). Option label = finding title + severity; description = the one-line failure mode.

3. Fixing (only what was selected):
   - Per repo, dispatch the implementer agent with the full list of selected findings for that repo (one dispatch per repo, not one per finding). All per-repo implementer dispatches MUST go out in one message — dispatch all repos concurrently.
   - Missing-test findings go to the test-engineer agent instead.
   - After fixes: run targeted tests via /octo:test's selection logic.
   - Then a focused skeptic-style re-check per fixed finding (reference /octo:review's verification protocol, don't restate).
   - Report per finding: FIXED (with file:line) or COULDN'T-FIX (with why).
   - Conventional commit per repo: `fix: address audit findings — <short list>`
   - Commit only in repos where the user selected fixes; NEVER push automatically.

4. If "Nothing — report only": end exactly as today (no changes made).


---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Parallel-first: dispatches that do not consume each other's output MUST go in a single
  message. Dispatching sequentially what could run concurrently is a defect, not a style
  choice. Cap ≈10 concurrent lanes; more work than lanes → batch waves.
- Read-only through the report. Nothing is modified unless you select fixes at the final step; pushes are never automatic.
- Reader-first output: lead with the outcome in one sentence; keep the visible reply short and dev-readable — only what changes the reader's next action. Full detail (complete reports, evidence, logs) goes to a file under `.claude/octo/reports/YYYY-MM-DD-<skill>-<slug>.md` with the path given in chat — never dumped into the conversation.
