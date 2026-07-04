#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'EOF'
import json
p = json.load(open(".claude-plugin/plugin.json"))
assert p["name"] == "octo", p
assert "description" in p and "version" in p
m = json.load(open(".claude-plugin/marketplace.json"))
assert m["name"] == "octo-marketplace"
assert m["plugins"][0]["source"] == "./"
EOF
