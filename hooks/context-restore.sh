#!/usr/bin/env bash
# octo context-restore — SessionStart(compact|resume): re-inject critical state.
set -uo pipefail
cat >/dev/null || true   # consume stdin

echo "octo context restore:"
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "- branch: $(git branch --show-current 2>/dev/null || echo detached)"
  DIRTY=$(git status --short 2>/dev/null | head -20)
  [ -n "$DIRTY" ] && { echo "- dirty files:"; echo "$DIRTY" | sed 's/^/    /'; }
  echo "- last commits:"; git log --oneline -5 2>/dev/null | sed 's/^/    /'
fi
echo "- rules: never push to protected branches; never --no-verify; surface assumptions explicitly"
if [ -f .claude/handoff.md ]; then
  echo "- handoff (.claude/handoff.md):"
  head -30 .claude/handoff.md | sed 's/^/    /'
fi
if [ -f .claude/octo/run/state.json ]; then
  echo "- active octo run detected (.claude/octo/run/) — resume with /octo:studio --resume"
fi
exit 0
