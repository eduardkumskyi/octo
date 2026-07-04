---
name: pr
description: Create a pull request: detect base branch, verify not protected, run lint/pre-commit if configured, push, open PR with a generated description that always carries an Assumptions section. Falls back to push + compare URL without gh.
argument-hint: "[base-branch]"
---

## Progress Contract

Register these steps as a native task list at Step 1, before beginning. After each step, update
`.claude/octo/status.json` with `{"phase": <step-name>, "step": <N>, "activity": <short-string>}`.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Steps: (1) resolve-base, (2) guard-branch, (3) lint, (4) push, (5) open-pr.

## Arguments

- **`[base-branch]`** — explicit base branch for the PR. If omitted, resolve via
  `git symbolic-ref refs/remotes/origin/HEAD` (strip to branch name); if unset, use `main` if
  it exists, else `master`. State the resolved base before proceeding.

## Workflow

### Step 1 — Resolve base

Determine the base branch using the rule above. Print:
`"base branch: <name> (source: <arg|detected>)."`

Update status: `{"phase": "resolve-base", "step": 1, "activity": "base resolved"}`.

### Step 2 — Guard current branch  ← STOP if protected

Get the current branch: `git rev-parse --abbrev-ref HEAD`.

**REFUSE** if the current branch matches any protected name: `main`, `master`, `staging`,
`production`, `qa`, `develop`, or the resolved repo default.

Print: `"REFUSED: current branch '<name>' is protected. Check out a feature branch and re-run."`
Do not proceed further.

Update status: `{"phase": "guard-branch", "step": 2, "activity": "branch verified"}`.

### Step 3 — Lint / pre-commit

Check whether the project configures a lint or pre-commit step (look for
`.pre-commit-config.yaml`, a `lint` or `check` target in `Makefile`, or a lint command in
`CLAUDE.md`). If found, run it. If it fails, report the output and stop — do not push broken
code.

If no lint config is found, skip silently and note `"no lint config detected."`.

Update status: `{"phase": "lint", "step": 3, "activity": "lint complete or skipped"}`.

### Step 4 — Push

Push the current branch to origin: `git push -u origin <current-branch>`.

Update status: `{"phase": "push", "step": 4, "activity": "branch pushed"}`.

### Step 5 — Open PR

**With `gh`**: run `gh pr create --base <base> --title <title> --body <body>`.

Derive the title from the branch name or the most recent commit subject (≤ 72 chars).

PR body template:

```
## Summary
<bullet points from commits on this branch not yet on base>

## Assumptions
<content of `## Assumptions` from the plan, or "None beyond the plan" if absent>

## Test plan
<bullet list of test files or manual checks run>
```

Carry the `## Assumptions` section verbatim from the plan file used in the preceding
`/octo:implement` run (`.claude/plans/` latest by name, or the plan whose slug matches the
branch context). The section is **always present**, even when empty — write
`"None beyond the plan"` rather than omitting it.

No AI attribution in the PR body, title, or any commit message — ever.

**Without `gh`**: push (Step 4 is already done), then print:

```
Compare URL: https://github.com/<org>/<repo>/compare/<base>...<current-branch>
Open the URL above to create a PR manually.
```

Derive the GitHub org/repo from `git remote get-url origin`.

Update status: `{"phase": "open-pr", "step": 5, "activity": "PR created or URL printed"}`.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (`main`, `master`, `qa`, `staging`).
- Never use `--no-verify` or force-push.
