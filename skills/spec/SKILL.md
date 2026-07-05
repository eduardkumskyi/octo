---
name: spec
description: "Turn an idea into a reviewed design doc before any planning: a one-question-at-a-time interview via question cards, then a spec covering architecture, data flow, error handling, and testing, self-reviewed for placeholders and contradictions. Feeds /octo:plan."
argument-hint: "<idea>"
---

## Progress Contract

Register these steps as a native task list at Step 1, before beginning the interview.
Report progress as "N steps remaining, size class S/M/L" — never wall-clock ETAs.

Register steps in the native task list named `🐙 <n>/<total> — <step name>`; update each to in_progress/completed as you go — the checklist is the user's primary progress view.

Steps: (1) read-context, (2) scope-check, (3) interview, (4) draft-spec,
(5) self-review, (6) save-spec, (7) await-approval.

## Arguments

- **`<idea>`** — the feature, system, or change to design. Free-form; keep it concise.
  `/octo:spec` translates it into a full design doc before any planning begins.

## Workflow

### Step 1 — Read project context

Read the host project's `CLAUDE.md`. If it is absent or missing a needed section:

- State what is missing explicitly.
- Continue with defaults — do not block on scaffolding.
- Detect what you can from repo artifacts (lockfiles, `Makefile`, `pyproject.toml`, CI config,
  `package.json`). Label every inferred convention `[DETECTED]`.


### Step 2 — Scope check

Assess whether the idea spans multiple independent subsystems (e.g. a new API endpoint, a
background worker, and a schema migration that could each be specced and planned separately).

**If yes**: state the decomposition explicitly and propose the breakdown FIRST — list the
sub-specs as distinct items and ask which to tackle first (via AskUserQuestion, options =
each sub-spec + "All of them in order (Recommended)"). Do not proceed past this step without
a scoping decision.

**If no**: proceed to Step 3 immediately.


### Step 3 — Interview

Conduct a one-question-at-a-time interview to gather enough context to write a complete,
unambiguous spec. Cover: purpose, users or consumers, constraints (perf, security, platform),
success criteria, and non-goals.

**Question discipline**:
- Ask exactly ONE question per exchange — never bundle multiple questions.
- Prefer AskUserQuestion wherever choices are enumerable: 2–4 concrete options, recommended
  first and labeled "(Recommended)", free prose only for genuinely open-ended questions.
- Stop when marginal questions stop changing the design (typically 4–8 questions total).
- If the user's answer resolves two pending questions at once, skip the resolved one.


### Step 4 — Draft the spec

Write the spec with these sections, sized to their actual complexity (YAGNI — omit sections
that are genuinely N/A rather than padding them):

- **Summary** — one paragraph; what this is and why it matters.
- **Goals & Non-goals** — bullet lists; non-goals are as important as goals.
- **Architecture** — components, boundaries, major dependencies; diagram in prose or ASCII.
- **Data flow** — how data enters, transforms, and exits the system; happy path + key edge
  cases.
- **Error handling** — failure modes, retry strategy, degraded-state behavior.
- **Testing approach** — unit / integration / e2e breakdown; what a passing test suite proves.
- **`## Assumptions`** — every non-obvious decision, each labeled `SAFE` or `RISKY`.
- **`## Open Questions`** — items that need resolution before or during implementation, with
  who owns the answer.


### Step 5 — Self-review pass

Before saving, scan the draft for:

1. **Placeholder scan** — no TBD, TODO, "to be defined", or blank sections.
2. **Internal contradictions** — does any section contradict another? Fix inline.
3. **Scope creep** — does the spec describe more than the agreed idea? Trim.
4. **Ambiguity check** — would a fresh implementer have to guess at any decision? Clarify.

Fix all issues inline. Do not save a draft that fails any of these checks.


### Step 6 — Save spec

1. Derive the slug: lower-case the idea, replace spaces and special characters with `-`,
   collapse runs of `-`. Example: `"OAuth token refresh flow"` → `oauth-token-refresh-flow`.

2. Write the spec to `.claude/octo/specs/YYYY-MM-DD-<slug>.md` using today's date.

3. Register `.claude/octo/` in `.git/info/exclude`: read the file (create if absent), append
   the line `.claude/octo/` **only if it is not already present**. Never modify the project's
   `.gitignore`. State this to the user.

4. Report the saved path.


### Step 7 — Await approval  ← STOP

Present a brief summary: spec title, section count, key architectural decisions, and any
`RISKY` assumptions that will need resolution before or during planning.

**STOP.** Use AskUserQuestion: "Spec saved — ready to plan?" with options:
- Run `/octo:plan` with this spec (Recommended)
- Revise a section first
- Stop here

On approval, offer `/octo:plan` and tell it to consume the spec at
`.claude/octo/specs/YYYY-MM-DD-<slug>.md` — plan carries the spec's Assumptions forward.


---

## Parallel-first law

Where interview questions do not depend on each other's answers, batch them into a single
AskUserQuestion multiSelect rather than sequential single-question exchanges. Where spec
sections can be drafted independently (e.g. Error handling and Testing approach share no
content), draft them in parallel sub-tasks rather than sequentially.

---

## Shared Conventions

- Commits: conventional format `type(scope): brief description` — no AI attribution,
  no `Co-Authored-By` lines of any kind.
- Never push directly to protected branches (protected branches — see the octo guard's list).
- Never use `--no-verify` or force-push.
- Parallel-first: dispatches that do not consume each other's output MUST go in a single
  message. Dispatching sequentially what could run concurrently is a defect, not a style
  choice. Cap ≈10 concurrent lanes; more work than lanes → batch waves.
