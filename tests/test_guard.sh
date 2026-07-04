#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
G=hooks/guard.sh

payload() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")"; }

expect_block() {
  if payload "$1" | bash "$G" 2>/dev/null; then echo "should have BLOCKED: $1"; exit 1; fi
}
expect_allow() {
  if ! payload "$1" | bash "$G" 2>/dev/null; then echo "should have ALLOWED: $1"; exit 1; fi
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

expect_allow 'git push origin feat/x'
expect_allow 'git push origin HEAD:feat/y'
expect_allow 'git status'
expect_allow 'rm -rf node_modules/foo'
expect_allow 'psql -c "SELECT 1"'
# non-Bash tools pass through
printf '{"tool_name":"Read","tool_input":{}}' | bash "$G"
