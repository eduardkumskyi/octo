# OpenCode adapter

## What the shim does

`octo-guard.js` is an OpenCode plugin that intercepts `tool.execute.before` for
bash-like tools (`bash`, `shell`, `run`) and delegates every command to the same
`hooks/guard.sh` that Claude Code's native `PreToolUse` hook uses. The guard
reads a JSON payload on stdin, exits 2 to block a command, or exits 0 to allow
it. When the guard exits 2, the shim throws an `Error` with the guard's stderr
message, which causes OpenCode to surface the block reason to the user and abort
the tool call. Any other non-zero exit (guard crash, missing dependency, etc.)
is treated as fail-open — identical to the native hook's behaviour — so a guard
misconfiguration never hard-stops your session. Non-bash tools are passed through
without inspection.

## Install

Symlink `octo-guard.js` into OpenCode's plugin directory for either the project
or the user. **Always use `ln -s` — do not copy the file** (see the warning
below).

```bash
# project-local (recommended)
mkdir -p .opencode/plugins
ln -s "$(pwd)/adapters/opencode/octo-guard.js" .opencode/plugins/octo-guard.js

# user-global
mkdir -p ~/.config/opencode/plugins
ln -s "$(pwd)/adapters/opencode/octo-guard.js" ~/.config/opencode/plugins/octo-guard.js
```

OpenCode loads every `*.js` file from the plugin directories on startup; no
further configuration is needed.

> **Warning — do not copy the file.** A copied shim cannot locate `guard.sh`
> because Node resolves `__dirname` to the copy's directory, not the repository
> root. The shim will print an `[octo-guard] guard.sh not found — guard is
> INACTIVE` warning on the first intercepted command and then fail-open (allow
> everything). If you must use a copy, set the `OCTO_GUARD` environment variable
> to the absolute path of `hooks/guard.sh` in your repository checkout:
>
> ```bash
> export OCTO_GUARD=/absolute/path/to/claude-octo/hooks/guard.sh
> ```

## Skills and CLAUDE.md

OpenCode reads `.claude/skills/` and `CLAUDE.md` natively, so running
`adapters/install.sh` (which installs skills into `.claude/skills/`) covers
the skills side automatically. No extra work is needed to share skills between
Claude Code and OpenCode.

## Agents

OpenCode agent files use a different schema from Claude Code's `AGENTS.md`.
OpenCode agents are declared with `mode` and `permission` fields rather than
the `tools` array used by Claude Code. See the official reference for the
current format:

<https://opencode.ai/docs/agents>

### Sharing agent definitions between Claude Code and OpenCode

A common convention is to keep `CLAUDE.md` as the authoritative file and
symlink it as `AGENTS.md` so both tools see the same high-level instructions:

```bash
ln -s CLAUDE.md AGENTS.md
```

Tool-specific fields (Claude Code's `tools` list vs OpenCode's `mode`/
`permission`) still need to live in their respective per-tool agent files;
only the shared prose/instructions can be unified this way.
