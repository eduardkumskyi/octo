---
name: queue
description: "Collect task descriptions all day, then run them unattended: each item becomes a studio mission in its own git worktree, ending in a branch + delivery digest. Come back to finished work."
argument-hint: "add <description> | list | run | clear"
---

## Progress Contract

**OCTO_ROOT** = `${CLAUDE_PLUGIN_ROOT}` when set; otherwise two directories above this skill's base directory (`skills/<name>/` sits at `<plugin-root>/skills/<name>/`). Resolve once at start.

Register steps as a native task list before doing any work.
Report progress as "N steps remaining" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to in_progress/completed as you go — the checklist is the user's primary progress view.

## Arguments

- **`add <description>`** — append a new item to the queue.
- **`list`** — show the current queue as a table.
- **`run`** — execute all pending items unattended, sequentially.
- **`clear`** — remove all done items from the queue file.

## Queue File

Queue state lives at `.claude/octo/queue.md`. Each item has the form:

```
## Q<n> — <description>

Status: pending|running|done|failed
Branch:
```

Register `.claude/octo/` in `.git/info/exclude` (append only if not already present; never modify `.gitignore`).

## Commands

### `add <description>`

Append a new item to `.claude/octo/queue.md`:

```
## Q<n> — <description>

Status: pending
Branch:
```

Where `n` is the next sequential number. Create the file with a `# Queue` header if absent.
Report: `"Q<n> added."`.

### `list`

Read `.claude/octo/queue.md` and print a table:

| # | Description | Status | Branch |
|---|-------------|--------|--------|

### `run`

For each item with `Status: pending`, in order:

1. Derive a slug from the description: lower-case, replace spaces and special characters
   with `-`, collapse runs of `-`.
2. Create an isolated git worktree:
   `git worktree add ../<repo-name>-q<n> -b octo/q<n>-<slug>` from the current HEAD.
3. Set `Status: running` in `.claude/octo/queue.md`.
4. Run the `/octo:studio` workflow inside the worktree, with these adjustments:
   - **Phase 1 (contract) is replaced**: the item description IS the mission. The studio
     derives acceptance criteria from the description using the consilium — seat: client
     advocate maps the description to observable, testable outcomes. Zero questions —
     this is unattended by definition.
   - All other studio phases (consilium-setup, milestone-loop, delivery) apply in full,
     including the state-write gate and blocked-event protocol.
   - The corrupt-state exception (Phase 4) may still halt an item: set `Status: failed`
     with reason appended under the item; continue to the next item.
5. On completion (delivery reached):
   - Set `Status: done`.
   - Set `Branch: octo/q<n>-<slug>`.
   - Append a one-line delivery digest under the item's entry in `.claude/octo/queue.md`.
6. Run `bash "$OCTO_ROOT/scripts/notify.sh" "octo queue" "done: Q<n> — <description>"`.
7. Continue to the next pending item.

Items run **sequentially** — one studio at a time. Parallel-first applies INSIDE each
mission (the studio's own agent dispatches are concurrent); the queue itself is serial.

Worktrees are left in place with their branches for the user's review. The user merges or
discards them manually.

### `clear`

Remove all items with `Status: done` from `.claude/octo/queue.md`. Report the count removed.

---

## Final Output for `run`

After all items have been processed, present a table as the chat output (not prose):

| Q# | Description | Status | Branch | Try it |
|----|-------------|--------|--------|--------|

`Try it` = the exact command from the item's delivery digest, or `—` if failed.

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
