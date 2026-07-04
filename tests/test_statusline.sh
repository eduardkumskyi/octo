#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
S=$(pwd)/statusline/octo-statusline.sh

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"; git init -q; git checkout -qb feat/x; git commit -qm init --allow-empty

OUT=$(bash "$S" </dev/null)
echo "$OUT" | grep -q "feat/x" || { echo "no branch shown: $OUT"; exit 1; }

mkdir -p .claude/octo
echo '{"phase":"build","step":"step 3/7","activity":"fixing tests"}' > .claude/octo/status.json
OUT=$(bash "$S" </dev/null)
echo "$OUT" | grep -q "build · step 3/7 · fixing tests" || { echo "bad status: $OUT"; exit 1; }
