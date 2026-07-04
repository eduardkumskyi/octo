#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGIN=$(pwd)
TMP=$(mktemp -d)
PORT=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
trap 'rm -rf "$TMP"; kill $SRV 2>/dev/null || true; pkill -f "serve.py --port $PORT" 2>/dev/null || true' EXIT
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
kill $SRV
