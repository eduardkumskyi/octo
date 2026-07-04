#!/usr/bin/env bash
# Mission Control dashboard server wrapper.
# Usage: serve.sh [--port N] [--open]
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"

PORT=8437
OPEN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="$2"
      shift 2
      ;;
    --open)
      OPEN=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$OPEN" -eq 1 ]]; then
  # Start server briefly in background, open browser, then exec foreground
  python3 "$PLUGIN_DIR/serve.py" --port "$PORT" &
  _BG=$!
  sleep 0.5
  if command -v open &>/dev/null; then
    open "http://127.0.0.1:$PORT/" 2>/dev/null || true
  elif command -v xdg-open &>/dev/null; then
    xdg-open "http://127.0.0.1:$PORT/" 2>/dev/null || true
  fi
  wait "$_BG"
else
  exec python3 "$PLUGIN_DIR/serve.py" --port "$PORT"
fi
