---
name: skill
description: Author a new skill, agent, or hook - into the octo plugin repo or a host project's .claude/. Knows the current frontmatter formats, hook events, and plugin layout; scaffolds, dry-runs, and commits.
argument-hint: "<what you want>"
---

## Progress Contract

Register these steps as a native task list at Step 2, before doing anything else. After each step,
update `.claude/octo/status.json` with `{"phase": <step-name>, "step": <N>, "activity": <short-string>}`.
Report progress as N steps remaining, size class S/M/L — never wall-clock ETAs.

Steps: (1) clarify, (2) register-progress, (3) scaffold, (4) validate, (5) commit.

## Canonical Format References

Before scaffolding, read these files — they are the source of truth for the formats you must follow:

**OCTO_ROOT** = `${CLAUDE_PLUGIN_ROOT}` when set; otherwise two directories above this skill's base directory (`skills/<name>/` sits at `<plugin-root>/skills/<name>/`). Resolve once at start.

- **Skill frontmatter + body**: `$OCTO_ROOT/skills/plan/SKILL.md`
- **Agent frontmatter + body**: `$OCTO_ROOT/agents/architect.md`
- **Hook event names and structure**: `$OCTO_ROOT/hooks/hooks.json`

Never guess formats from memory. Read the canonical files first.

## Workflow

### Step 1 — Clarify

Determine what the user wants to author (skill, agent, or hook) and where it should land:

- **Octo repo** (`/Users/…/claude-octo` or the directory containing `skills/` and `agents/`) —
  the artifact will live inside this plugin and be committed here.
- **Host project `.claude/`** — a skill or agent is scaffolded into the host project's
  `.claude/skills/<name>/SKILL.md` or `.claude/agents/<name>.md`.

If any of these are unclear, ask one focused question per unknown before proceeding.

Update status: `{"phase": "clarify", "step": 1, "activity": "target and type confirmed"}`.

### Step 2 — Register progress

Create the native task list for this session (all five steps).

Update status: `{"phase": "register-progress", "step": 2, "activity": "task list created"}`.

### Step 3 — Scaffold

**Skills** (Agent Skills spec — enforced by `tests/test_artifacts_structure.sh`):

1. Directory name must exactly match the `name` frontmatter field.
2. `name` and `description` are required; `description` must be non-empty.
3. Add an `argument-hint` if the skill accepts user arguments.
4. Body must describe the workflow the skill orchestrates, not just what it does.
5. Target path: `skills/<name>/SKILL.md`.

**Agents**:

1. Filename (without `.md`) must exactly match the `name` frontmatter field.
2. `name`, `description`, and `model` are required.
3. Body must include a "Before Doing Anything: Read CLAUDE.md" preamble (the validator checks for
   the string `CLAUDE.md` in the body).
4. Specify `disallowedTools` for read-only agents.
5. Target path: `agents/<name>.md`.

**Hooks** (octo repo targets only):

1. Read `hooks/hooks.json` for the allowed event names: `PreToolUse`, `PostToolUse`,
   `SessionStart`, `Stop`.
2. Write the hook script to `hooks/<name>.sh` and add the entry to `hooks/hooks.json`.
3. Keep the hook script small and focused; document its regex patterns with inline comments.

Show the draft artifact to the user and wait for approval before writing.

Update status: `{"phase": "scaffold", "step": 3, "activity": "draft artifact ready"}`.

### Step 4 — Validate

**Octo repo targets**: run `bash tests/run.sh` from the repo root. All tests must PASS. If any
fail, fix the artifact — do not modify the tests. Report the test output.

**Host project targets**: re-read the scaffolded file and verify:

- Frontmatter parses (no unclosed quotes, correct YAML indentation).
- Required fields are present and non-empty.
- Directory/filename matches the `name` field.

Update status: `{"phase": "validate", "step": 4, "activity": "tests passed or file verified"}`.

### Step 5 — Commit (octo repo targets only)

For octo-repo additions, commit with a conventional-format message:

```bash
git add skills/<name> agents/<name>.md hooks/
git commit -m "feat(skills): /octo:<name> <one-line description>"
```

Never amend existing commits. Never use `--no-verify` or force-push.
Never include `Co-Authored-By` lines or AI attribution.

For host-project targets, report the scaffolded path and leave committing to the user.

Update status: `{"phase": "commit", "step": 5, "activity": "done"}`.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
