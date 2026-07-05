---
name: test
description: Run only the tests affected by the current diff, printing which tests were selected and why. Full suite with --all. Reads the project's test command and subset syntax from CLAUDE.md.
argument-hint: "[scope | --all]"
---

## Progress Contract

Register these steps as a native task list at Step 1, before running.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Steps: (1) read-config, (2) compute-diff, (3) select-tests, (4) run-tests.

## Arguments

- **`scope`** — optional path. Test files/dirs → run exactly those (skip diff mapping). Source paths → restrict diff selection to changes under that subtree. Mutually exclusive with `--all`; if both are given, error and ask the user to choose.
- **`--all`** — full suite. Mutually exclusive with `scope`.

## Workflow

### Step 1 — Read project config

Read the host project's `CLAUDE.md` for:

- `test_command` — command used to run tests.
- `subset_syntax` — how to pass a file or module subset (e.g. `pytest {files}`).
- `weight` — `heavy` (suite takes ~5+ minutes) or `light`.

If `CLAUDE.md` is absent or missing a `test_command`:

- State explicitly that no test command was found.
- Detect from repo artifacts: `pyproject.toml` or `pytest.ini` → `pytest`; `manage.py` →
  `python manage.py test`; `package.json` → `npm test`; `go.mod` → `go test ./...`;
  `Cargo.toml` → `cargo test`.
- Announce what was detected before running.


### Step 2 — Compute diff

Resolve the base branch: `git symbolic-ref refs/remotes/origin/HEAD` (strip to branch name); if unset, use `main` if it exists, else `master`. State the chosen base in the selection printout.

Combine `git diff HEAD` (working tree + index) with commits on the current branch not yet on
the base branch.

If the combined diff is **empty**:
- Report: "no changes detected."
- Suggest re-running with `--all`.
- Exit without running tests.

If `--all` was passed, skip directly to Step 4.


### Step 3 — Select tests

Map changed source files to test files using, **in order**:

1. **Explicit rules** in host `CLAUDE.md` (e.g. `test_mapping: {src/foo.py: tests/test_foo.py}`).
2. **Mirrored paths** — `src/foo/bar.py` → `tests/foo/test_bar.py` (or `bar_test.py`).
3. **Same-name** — any file named `test_<module>` or `<module>_test` anywhere in the repo.
4. **Import heuristics** — test files that import the changed module.

**ALWAYS** print the selection and rationale before running:

```
selected 4 of 812 test files: tests/foo/test_bar.py (mirrored path), tests/test_baz.py (import match)
```

Silent gaps are forbidden. If a changed file maps to no test file, state that explicitly.

If the selection is empty and `weight: heavy`:
- Report: "no targeted tests found; run with --all to execute the full suite."
- Exit.

If the selection is empty and `weight: light`:
- Report the gap and run the full suite.


### Step 4 — Run tests  ← STOP when heavy + --all

If `weight: heavy` and `--all` was passed, confirm with the user before running the full suite.

Run using the resolved command and `subset_syntax` for the selected files.
For `--all` (once confirmed on heavy, or immediately on light), omit the file filter.


---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Parallel-first: dispatches that do not consume each other's output MUST go in a single
  message. Dispatching sequentially what could run concurrently is a defect, not a style
  choice. Cap ≈10 concurrent lanes; more work than lanes → batch waves.
