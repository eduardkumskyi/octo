---
name: audit
description: "PR-style pre-merge audit: exhaustive, skeptical, read-only review of the current branch against an auto-detected base, across companion repos automatically. Reviews like a senior engineer trying to block a risky merge — severity-graded findings with concrete failure modes, cross-repo compatibility, must-fix vs safe-to-defer."
argument-hint: "[base-branch] [--repos <path>...]"
---

## Progress Contract

Register these steps as a native task list at Step 1, before any resolution work.
After each step, update `.claude/octo/status.json` with
`{"phase": <step-name>, "step": <N>, "activity": <short-string>}`.
Report progress as "N steps remaining" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to
in_progress/completed as you go — the checklist is the user's primary progress view.

Steps: (1) resolve-matrix, (2) per-repo-review, (3) cross-repo-lens, (4) skeptic-verify,
(5) report.

## Arguments

- **`[base-branch]`** — explicit base branch to diff against. If omitted, resolved
  automatically (see Step 1). Any positional argument that does not start with `--` is
  treated as the base branch.
- **`--repos <path>...`** — one or more paths to companion repos to include in the audit.
  Overrides CLAUDE.md companion-repo discovery and auto-detection entirely.

## Workflow

### Step 1 — Resolve audit matrix

**Base branch resolution** (first match wins; always announce the chosen base and why):

1. Explicit argument — a positional arg provided by the user.
2. `review base:` or `audit base:` directive in the host project's `CLAUDE.md` — scan for
   either key.
3. `origin/staging` exists — check with
   `git ls-remote --heads origin staging`; if the ref is listed, use `staging`.
4. Repo default — `git symbolic-ref refs/remotes/origin/HEAD` (strip to branch name);
   if unset, try `main`, then `master`.

After resolving the base, fetch it: `git fetch origin <base>`.

**Companion repo resolution** (first match wins):

1. `--repos` arguments — use exactly the listed paths.
2. `companion repos:` line in the host `CLAUDE.md` — parse the paths from that line.
3. Auto-detection — list sibling directories of the current repo (same parent directory)
   that are git repos (contain `.git`). For each, check whether it has a local or remote
   branch named **exactly** like the current repo's active branch
   (`git ls-remote --heads origin <branch>` inside the sibling). Include every sibling
   that matches. Announce each included companion:
   `"detected companion <abs-path> on branch <name>"`.
   Announce each excluded sibling and why (no matching branch, not a git repo, etc.).

Each companion is audited against its **own** auto-resolved base using the same four-step
resolution above (run inside the companion's directory).

**Audit matrix**: print a table — Repo | Branch | Base — covering the host repo and every
companion before proceeding. This is the contract for the rest of the run.

Register the 🐙 task checklist now.

Update status: `{"phase": "resolve-matrix", "step": 1, "activity": "audit matrix announced"}`.

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

Update status: `{"phase": "per-repo-review", "step": 2, "activity": "all lenses returned"}`.

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

Update status: `{"phase": "cross-repo-lens", "step": 3, "activity": "integration lens complete"}`.

### Step 4 — Skeptic verification pass

Follow the exact same skeptic protocol as `/octo:review` Step 3 — reference it; do not
restate it here. Apply it to every finding collected from Steps 2 and 3:

- Dispatch a fresh skeptic subagent per finding with the finding verbatim and the
  surrounding diff hunk or file section.
- The skeptic returns `REFUTED: <reason>` or `UPHELD: <reason>`. Uncertain ⇒ UPHELD.
- Only REFUTED findings are dropped; UPHELD findings carry forward to the report.
- Model scales with stakes: `haiku` for LOW/MEDIUM; `inherit` for HIGH/CRITICAL.

Update status: `{"phase": "skeptic-verify", "step": 4, "activity": "k findings confirmed"}`.

### Step 5 — Report

Produce the audit report per the **Report Contract** below.

**READ-ONLY**: never apply fixes, never create commits, never modify the working tree.
Confirmed HIGH/CRITICAL findings become lesson-card candidates — follow the same card
contract as `/octo:review` Step 5 (write `.claude/octo/lessons/<kebab-slug>.md`; same
50-card cap, same slug/body rules). Do not write cards for MEDIUM/LOW findings unless they
reveal a recurring anti-pattern already present in the lessons store.

Update status: `{"phase": "report", "step": 5, "activity": "audit complete"}`.

---

## Report Contract

This format is binding. Review it like a senior engineer trying to block a risky merge.

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

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Fan-out: all reviewer dispatches for a batch go in a **single message** — serial dispatch
  is not acceptable when parallel execution halves elapsed time.
- READ-ONLY throughout: the audit skill never modifies the working tree, never commits,
  never pushes.
