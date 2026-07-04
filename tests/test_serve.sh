#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGIN=$(pwd)
TMP=$(mktemp -d)
SRV2_LOG=$(mktemp)
SRV2=0
PORT=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
trap 'rm -rf "$TMP" "$SRV2_LOG"; kill $SRV 2>/dev/null || true; [ "$SRV2" -gt 0 ] && kill "$SRV2" 2>/dev/null || true; pkill -f "serve.py --port $PORT" 2>/dev/null || true' EXIT
mkdir -p "$TMP/.claude/octo/run"
cp tests/fixtures/run/* "$TMP/.claude/octo/run/"
( cd "$TMP" && exec python3 "$PLUGIN/dashboard/serve.py" --port "$PORT" >"$TMP/server.log" 2>&1 ) &
SRV=$!
sleep 1
curl -sf "http://127.0.0.1:$PORT/run/state.json" | grep -q "toy mission" || { echo "state not served"; exit 1; }
curl -sf "http://127.0.0.1:$PORT/" >/dev/null || { echo "index not served"; exit 1; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/run/../../secret" | grep -qE "^(400|403|404)$" || { echo "traversal not rejected"; exit 1; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/run/%2e%2e/secret" | grep -qE "^(400|403|404)$" || { echo "encoded traversal not rejected"; exit 1; }
curl -sI "http://127.0.0.1:$PORT/run/state.json" | grep -qi "no-cache" || { echo "missing no-cache"; exit 1; }
HTML=$(curl -sf "http://127.0.0.1:$PORT/")
for id in board lanes decisions burndown eta; do
  echo "$HTML" | grep -q "id=\"$id\"" || { echo "missing #$id"; exit 1; }
done
echo "$HTML" | grep -qi "octo" || { echo "no branding"; exit 1; }
echo "$HTML" | grep -q "cdn\." && { echo "external CDN found"; exit 1; } || true

# Multi-session: second server on the same port must auto-select a different port
( cd "$TMP" && exec python3 "$PLUGIN/dashboard/serve.py" --port "$PORT" >"$SRV2_LOG" 2>&1 ) &
SRV2=$!
sleep 1
URL2=$(grep -oE 'http://127\.0\.0\.1:[0-9]+/' "$SRV2_LOG" | head -1)
[ -n "$URL2" ] || { echo "second server did not print URL"; exit 1; }
PORT2=$(echo "$URL2" | grep -oE '[0-9]+' | tail -1)
[ "$PORT2" != "$PORT" ] || { echo "second server reused same port ($PORT)"; exit 1; }
curl -sf "$URL2" >/dev/null || { echo "second server not reachable at $URL2"; exit 1; }
kill "$SRV2"; SRV2=0

kill $SRV
