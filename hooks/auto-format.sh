#!/usr/bin/env bash
# octo auto-format — PostToolUse(Edit|Write): format ONLY the edited file.
# Missing config or binary => silent skip. Never blocks (always exit 0).
set -uo pipefail

find_up() {  # find_up <start_dir> <name>...
  local d=$1; shift
  local i=0
  while [ "$d" != "/" ] && [ $i -lt 30 ]; do
    for n in "$@"; do [ -f "$d/$n" ] && return 0; done
    d=$(dirname "$d"); i=$((i+1))
  done
  return 1
}

INPUT=$(cat)
FILE=$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception: pass' <<<"$INPUT")
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

case "$FILE" in
  *.py)
    find_up "$(dirname "$FILE")" pyproject.toml ruff.toml .ruff.toml \
      && command -v ruff >/dev/null 2>&1 && ruff format "$FILE" >/dev/null 2>&1 || true ;;
  *.js|*.jsx|*.ts|*.tsx|*.css|*.json|*.md)
    find_up "$(dirname "$FILE")" package.json && command -v prettier >/dev/null 2>&1 \
      && prettier --write "$FILE" >/dev/null 2>&1 || true ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" >/dev/null 2>&1 || true ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE" >/dev/null 2>&1 || true ;;
esac
exit 0
