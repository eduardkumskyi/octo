#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
H=$(pwd)/hooks/verify-done.sh

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"; git init -q; git commit -qm init --allow-empty
echo "code" > app.py   # dirty source file

T_NO=$TMP/no_tests.jsonl;  echo '{"type":"tool_use","command":"git status"}' > "$T_NO"
T_YES=$TMP/tests.jsonl;    echo '{"type":"tool_use","command":"pytest tests/ -x"}' > "$T_YES"

OUT=$(printf '{"transcript_path":"%s"}' "$T_NO" | bash "$H")
echo "$OUT" | grep -q "systemMessage" && echo "$OUT" | grep -qi "no test" || { echo "expected notice, got: $OUT"; exit 1; }

OUT=$(printf '{"transcript_path":"%s"}' "$T_YES" | bash "$H")
[ -z "$OUT" ] || { echo "expected silence, got: $OUT"; exit 1; }

# missing transcript: silent, exit 0
printf '{"transcript_path":"/nope.jsonl"}' | bash "$H" >/dev/null
