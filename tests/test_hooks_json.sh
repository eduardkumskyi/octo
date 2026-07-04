#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'EOF'
import json, os
h = json.load(open("hooks/hooks.json"))["hooks"]
def cmds(ev): return [x["command"] for g in h[ev] for x in g["hooks"]]
assert any("guard.sh" in c for c in cmds("PreToolUse"))
assert h["PreToolUse"][0]["matcher"] == "Bash"
assert any("auto-format.sh" in c for c in cmds("PostToolUse"))
assert h["PostToolUse"][0]["matcher"] == "Edit|Write"
assert any("context-restore.sh" in c for c in cmds("SessionStart"))
assert h["SessionStart"][0]["matcher"] == "compact|resume"
assert any("verify-done.sh" in c for c in cmds("Stop"))
for ev in ("PreToolUse","PostToolUse","SessionStart","Stop"):
    for c in cmds(ev):
        assert c.startswith("${CLAUDE_PLUGIN_ROOT}/hooks/"), c
        assert os.path.exists(c.replace("${CLAUDE_PLUGIN_ROOT}", ".")), c
EOF
