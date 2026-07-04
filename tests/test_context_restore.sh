#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
H=$(pwd)/hooks/context-restore.sh

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init -q; git commit -qm init --allow-empty
echo dirty > f.txt
mkdir -p .claude/octo/run
echo "GOAL: finish octo" > .claude/handoff.md
echo '{"mission":"toy game"}' > .claude/octo/run/state.json

OUT=$(printf '{"source":"compact"}' | bash "$H")
echo "$OUT" | grep -q "branch:"           || { echo "no branch"; exit 1; }
echo "$OUT" | grep -q "f.txt"             || { echo "no dirty files"; exit 1; }
echo "$OUT" | grep -q "GOAL: finish octo" || { echo "no handoff"; exit 1; }
echo "$OUT" | grep -q "active octo run"   || { echo "no run pointer"; exit 1; }
echo "$OUT" | grep -qi "protected"        || { echo "no rules"; exit 1; }

# outside a git repo: still exits 0
cd /; printf '{"source":"resume"}' | bash "$H" >/dev/null
