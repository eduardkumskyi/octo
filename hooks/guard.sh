#!/usr/bin/env bash
# octo guard — PreToolUse safety hook. JSON on stdin; exit 2 blocks.
# Defense-in-depth, NOT a sandbox: regex-based; does not see through shell
# variables or heredocs. Known limits are documented in the README.
set -uo pipefail

INPUT=$(cat)

json_get() {  # json_get <python-expr-over-d>
  python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
try: print(eval(sys.argv[1]))
except Exception: pass' "$1" <<<"$INPUT"
}

TOOL=$(json_get 'd.get("tool_name","")')
[ "$TOOL" = "Bash" ] || exit 0
CMD=$(json_get 'd.get("tool_input",{}).get("command","")')
[ -n "$CMD" ] || exit 0

block() { echo "octo guard BLOCKED: $1" >&2; exit 2; }

# protected branches: defaults ∪ repo default ∪ .claude/octo.json override
BRANCHES="main master staging production qa develop"
DEF=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||' || true)
[ -n "$DEF" ] && BRANCHES="$BRANCHES $DEF"
if [ -f .claude/octo.json ]; then
  EXTRA=$(python3 -c 'import json,re
branches=json.load(open(".claude/octo.json")).get("protected_branches",[])
safe=[b for b in branches if re.fullmatch(r"[A-Za-z0-9._/-]+",b)]
print(" ".join(safe))' 2>/dev/null || true)
  [ -n "$EXTRA" ] && BRANCHES="$BRANCHES $EXTRA"
fi
BR_RE=$(echo "$BRANCHES" | tr ' ' '\n' | sort -u | paste -sd'|' -)

printf '%s\n' "$CMD" | grep -qE "git\s+push(\s|$)" && \
  printf '%s\n' "$CMD" | grep -qE "(^|\s)(-f|--force)(\s|$)" && block "force push"
printf '%s\n' "$CMD" | grep -qE "git\s+push.*--mirror" && block "push --mirror force-updates all refs"
printf '%s\n' "$CMD" | grep -qE "git\s+push\s+.*\b(origin|upstream)\s+\+?($BR_RE)\b" && block "push to protected branch"
printf '%s\n' "$CMD" | grep -qE "git\s+push\s+.*:\+?($BR_RE)(\s|$)" && block "push to protected branch via refspec"
printf '%s\n' "$CMD" | grep -qE "git\s+[^|;&]*--no-verify" && block "--no-verify"
printf '%s\n' "$CMD" | grep -qE "git\s+reset\s+--hard" && block "git reset --hard (use git stash)"
printf '%s\n' "$CMD" | grep -qE "rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\s+(/|\./?(\s|$)|\*|src/)" && block "rm -rf on root/cwd/src"
printf '%s\n' "$CMD" | grep -qiE "\b(DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE|DELETE\s+FROM)\b" \
  && printf '%s\n' "$CMD" | grep -qiE "\b(psql|mysql|sqlite3|docker\s+exec)\b" \
  && block "destructive SQL via DB CLI"
printf '%s\n' "$CMD" | grep -qE "manage\.py\s+dbshell" && block "direct DB shell (use ORM/management commands)"

# project-specific rules (host repo): sourced with $CMD and block() available
if [ -f .claude/hooks/guard-extra.sh ]; then
  # shellcheck disable=SC1091
  . .claude/hooks/guard-extra.sh || true
fi

exit 0
