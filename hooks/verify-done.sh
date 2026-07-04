#!/usr/bin/env bash
# octo verify-done — Stop hook: gentle nudge if code changed but no tests ran.
# Non-blocking by design (always exit 0): a hard block here causes more
# friction than it saves.
set -uo pipefail

INPUT=$(cat)
TRANSCRIPT=$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("transcript_path",""))
except Exception: pass' <<<"$INPUT")

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
CHANGED=$(git status --short 2>/dev/null | grep -cE '\.(py|js|jsx|ts|tsx|go|rs|rb|java|php|c|cpp|h)$' || true)
[ "$CHANGED" -gt 0 ] || exit 0
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

if ! grep -qiE '(pytest|manage\.py test|npm (test|run test)|yarn test|go test|cargo test|jest|vitest|rspec|phpunit|ruff|eslint|pre-commit)' "$TRANSCRIPT"; then
  printf '{"systemMessage": "🐙 source files changed this session but no test/lint run found — consider /octo:test before calling it done."}\n'
fi
exit 0
