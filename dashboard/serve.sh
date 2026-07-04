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
  if command -v open &>/dev/null; then
    ( sleep 0.5; open "http://127.0.0.1:$PORT/" ) &
  elif command -v xdg-open &>/dev/null; then
    ( sleep 0.5; xdg-open "http://127.0.0.1:$PORT/" ) &
  fi
  exec python3 "$PLUGIN_DIR/serve.py" --port "$PORT"
else
  exec python3 "$PLUGIN_DIR/serve.py" --port "$PORT"
fi
