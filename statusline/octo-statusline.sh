#!/usr/bin/env bash
# octo statusline — one line: 🐙 branch · phase · step · activity
set -uo pipefail
[ -t 0 ] || cat >/dev/null 2>&1 || true   # harness may pipe session JSON; drain only if stdin is not a tty

BR=$(git branch --show-current 2>/dev/null || true)
LINE="🐙"
[ -n "$BR" ] && LINE="$LINE $BR"
if [ -f .claude/octo/status.json ]; then
  S=$(python3 -c 'import json
try:
  d=json.load(open(".claude/octo/status.json"))
  print(" · ".join(x for x in (d.get("phase"),d.get("step"),d.get("activity")) if x))
except Exception: pass' 2>/dev/null || true)
  [ -n "$S" ] && LINE="$LINE | $S"
fi
echo "$LINE"
