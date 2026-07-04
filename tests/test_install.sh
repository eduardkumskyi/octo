#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGIN=$(pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

HOME="$TMP" bash adapters/install.sh >/dev/null
[ -L "$TMP/.claude/skills/octo-plan" ] || { echo "claude skill link missing"; exit 1; }
[ -L "$TMP/.agents/skills/octo-review" ] || { echo "agents skill link missing"; exit 1; }
[ -L "$TMP/.claude/agents/architect.md" ] || { echo "agent link missing"; exit 1; }
[ "$(readlink "$TMP/.claude/skills/octo-plan")" = "$PLUGIN/skills/plan" ] || { echo "wrong target"; exit 1; }

# idempotent
HOME="$TMP" bash adapters/install.sh >/dev/null

# never overwrite a real dir
rm "$TMP/.claude/skills/octo-plan"; mkdir "$TMP/.claude/skills/octo-plan"
OUT=$(HOME="$TMP" bash adapters/install.sh)
echo "$OUT" | grep -qi "skip" || { echo "no skip warning"; exit 1; }
[ -d "$TMP/.claude/skills/octo-plan" ] && [ ! -L "$TMP/.claude/skills/octo-plan" ] || { echo "overwrote real dir"; exit 1; }
rmdir "$TMP/.claude/skills/octo-plan"

# uninstall removes only our links
touch "$TMP/.claude/agents/mine.md"
ln -s /tmp "$TMP/.claude/agents/foreign.md"
HOME="$TMP" bash adapters/install.sh --uninstall >/dev/null
[ ! -e "$TMP/.claude/skills/octo-review" ] || { echo "uninstall left link"; exit 1; }
[ -f "$TMP/.claude/agents/mine.md" ] || { echo "uninstall removed foreign file"; exit 1; }
[ -L "$TMP/.claude/agents/foreign.md" ] || { echo "uninstall removed foreign symlink"; exit 1; }
