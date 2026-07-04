#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
G=hooks/guard.sh

payload() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")"; }

# Fix 3: helpers assert exit code 2 and "BLOCKED" in stderr for blocks; exit 0 for allows
expect_block() {
  local out ec=0
  out=$(payload "$1" | bash "$G" 2>&1) || ec=$?
  if [ "$ec" -ne 2 ]; then echo "should have BLOCKED (exit 2, got $ec): $1"; exit 1; fi
  if ! echo "$out" | grep -q "BLOCKED"; then echo "no BLOCKED in stderr: $1"; exit 1; fi
}
expect_allow() {
  local ec=0
  payload "$1" | bash "$G" 2>/dev/null || ec=$?
  if [ "$ec" -ne 0 ]; then echo "should have ALLOWED (exit 0, got $ec): $1"; exit 1; fi
}

expect_block 'git push --force origin feat/x'
expect_block 'git push -f'
expect_block 'git push origin main'
expect_block 'git push origin qa'
expect_block 'git commit --no-verify -m x'
expect_block 'git reset --hard HEAD~1'
expect_block 'rm -rf /'
expect_block 'rm -rf ./'
expect_block 'rm -rf src/'
expect_block 'psql -c "DROP TABLE users"'
expect_block 'docker exec db psql -c "TRUNCATE posts"'
expect_block 'python manage.py dbshell'
# refspec pushes to protected branches must be blocked
expect_block 'git push origin HEAD:main'
expect_block 'git push origin feat/x:qa'
expect_block 'git push --force-with-lease origin HEAD:master'
# Fix 1: +refspec on protected branch and --mirror must be blocked
expect_block 'git push origin +main'
expect_block 'git push --mirror origin'
# Fix 2: branch named fix-f must not trigger the force-flag rule
expect_allow 'git push origin fix-f'
# Fix 1: +refspec on non-protected branch must be allowed
expect_allow 'git push origin +feat/x'

expect_allow 'git push origin feat/x'
expect_allow 'git push origin HEAD:feat/y'
expect_allow 'git status'
expect_allow 'rm -rf node_modules/foo'
expect_allow 'psql -c "SELECT 1"'
# non-Bash tools pass through
printf '{"tool_name":"Read","tool_input":{}}' | bash "$G"

# extensibility: octo.json branches + guard-extra.sh
TMP=$(mktemp -d)
cp -r hooks "$TMP/"
mkdir -p "$TMP/.claude/hooks"
echo '{"protected_branches":["release"]}' > "$TMP/.claude/octo.json"
cat > "$TMP/.claude/hooks/guard-extra.sh" <<'EOF'
echo "$CMD" | grep -q "forbidden-cmd" && block "project rule"
EOF
run_in() { ( cd "$TMP" && payload "$1" | bash hooks/guard.sh 2>/dev/null ); }
if run_in 'git push origin release'; then echo "octo.json branch not enforced"; exit 1; fi
if run_in 'forbidden-cmd now'; then echo "guard-extra.sh not sourced"; exit 1; fi
run_in 'git push origin feat/y' || { echo "extra rules over-blocked"; exit 1; }
rm -rf "$TMP"

# Fix 4: BR_RE sanitization — bad*branch in octo.json must not break the regex
TMP2=$(mktemp -d)
cp -r hooks "$TMP2/"
mkdir -p "$TMP2/.claude"
echo '{"protected_branches":["release","bad*branch"]}' > "$TMP2/.claude/octo.json"
if ( cd "$TMP2" && payload 'git push origin release' | bash hooks/guard.sh 2>/dev/null ); then
  echo "sanitized octo.json: release should still be blocked"; exit 1
fi
( cd "$TMP2" && payload 'git push origin feat/y' | bash hooks/guard.sh 2>/dev/null ) \
  || { echo "sanitized octo.json: feat/y should still be allowed"; exit 1; }
rm -rf "$TMP2"
