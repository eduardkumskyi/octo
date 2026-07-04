---
name: watch
description: "Open Mission Control: a local zero-dependency dashboard showing the active run - milestone board, agent lanes, decision feed, review burndown, and pace-based honest ETAs. --terminal runs the one-line octo wave animation instead."
argument-hint: "[--terminal | --port N]"
---

## Overview

`/octo:watch` is a **read-only** observer — it writes nothing to the run state and does not
affect an in-progress build or studio session.

Two modes:

| Flag | What runs | Foreground/background |
|------|-----------|-----------------------|
| _(none)_ | `dashboard/serve.sh --open` — full Mission Control web UI | background |
| `--terminal` | prints the command the user should run in their own terminal | n/a — hands off to user |
| `--port N` | same as default, but overrides the requested port (default: 8437; auto-increments if busy) | background |

## Default mode — Mission Control dashboard

Run `dashboard/serve.sh` from the **host project root** (the directory where `.claude/octo/run/`
lives). This is critical: the server resolves `/run/*` requests against the current working
directory, so launching from the wrong directory will serve an empty or wrong run.

Resolve the plugin directory via `${CLAUDE_PLUGIN_ROOT}` when that variable is set; otherwise
locate `serve.sh` relative to the octo plugin's own directory.

```bash
# Start in background, open the browser automatically
bash "${CLAUDE_PLUGIN_ROOT}/dashboard/serve.sh" --open &
```

With a custom port:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/dashboard/serve.sh" --port 9000 --open &
```

Report the URL to the user immediately after starting. Read it from the line `serve.py` prints
to stdout — it has the form `octo dashboard: http://127.0.0.1:<port>/`. Do **not** assume port
8437: if the port was busy, `serve.py` auto-incremented to the next free port (up to +9).

> Mission Control is live at **http://127.0.0.1:&lt;port&gt;/** (read from serve.py output).
> Stop it with `kill %1` or `kill <PID>` when done.

The dashboard auto-refreshes. It shows:
- **Milestone board** — status of every milestone in the current run
- **Agent lanes** — which implementer/test/review agents are active
- **Decision feed** — consilium rulings read from events.jsonl (decision events)
- **Review burndown** — open findings vs. resolved, per iteration
- **Pace-based ETAs** — honest estimates derived from completed steps; never wall-clock guesses

To stop: `kill <PID>` or `kill %1` if it is still a shell job.

## `--terminal` mode — wave animation

When `--terminal` is passed, **do not run the animation via a Bash tool**. It is an infinite
loop and cannot run interactively inside a session. Instead, print the exact command for the
user to run in their own terminal window:

```
Run this in a separate terminal:

    python3 /path/to/octo/terminal/octo-anim.py

Resolve the path via ${CLAUDE_PLUGIN_ROOT} when that variable is set; otherwise use the
known path to the octo repo's terminal/ directory.
```

The passive default is the **statusline** (`statusline/octo-statusline.sh`, wired via the
`statusLine` setting in your harness config) — always visible without any command.

Never attempt to run `octo-anim.py` via a Bash tool. Never use `timeout` as a workaround.

## Launching watch from build / studio

Both `/octo:build` (Step 1) and `/octo:studio` (Phase 1) offer to launch `/octo:watch`
automatically at the start of a run. Accept the offer to observe progress without polling.

## What this skill does NOT do

- Does **not** write to `.claude/octo/run/` or any other run-state file.
- Does **not** modify `.claude/octo/status.json`.
- Does **not** start, pause, or alter an in-progress build or studio session.
- Does **not** require a running agent — it can be opened before, during, or after a run.
