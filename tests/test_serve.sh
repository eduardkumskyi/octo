#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGIN=$(pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"; kill $SRV 2>/dev/null || true' EXIT
mkdir -p "$TMP/.claude/octo/run"
cp tests/fixtures/run/* "$TMP/.claude/octo/run/"
PORT=8497
( cd "$TMP" && python3 "$PLUGIN/dashboard/serve.py" --port $PORT & echo $! > "$TMP/pid" )
SRV=$(cat "$TMP/pid"); sleep 1
curl -sf "http://127.0.0.1:$PORT/run/state.json" | grep -q "toy mission" || { echo "state not served"; exit 1; }
curl -sf "http://127.0.0.1:$PORT/" >/dev/null || { echo "index not served"; exit 1; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/run/../../secret" | grep -qE "^(400|403|404)$" || { echo "traversal not rejected"; exit 1; }
curl -sI "http://127.0.0.1:$PORT/run/state.json" | grep -qi "no-cache" || { echo "missing no-cache"; exit 1; }
kill $SRV
