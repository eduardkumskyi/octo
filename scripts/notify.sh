#!/usr/bin/env bash
# octo notify — desktop notification; silent no-op without a notifier. Always exit 0.
set -uo pipefail
TITLE=${1:-octo}; MSG=${2:-}
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\"" >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$TITLE" "$MSG" >/dev/null 2>&1 || true
fi
exit 0
