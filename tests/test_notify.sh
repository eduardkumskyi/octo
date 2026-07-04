#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
N=$(pwd)/scripts/notify.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/osascript" <<'EOF'
#!/usr/bin/env bash
echo "OSA:$*" >> "${NOTIFY_LOG}"
EOF
chmod +x "$TMP/bin/osascript"
NOTIFY_LOG="$TMP/log" PATH="$TMP/bin:$PATH" bash "$N" "octo" "milestone verified"
grep -q "milestone verified" "$TMP/log" || { echo "osascript not invoked"; exit 1; }
# no notifier available -> silent success
PATH="/usr/bin:/bin" bash "$N" "octo" "x" >/dev/null 2>&1
