#!/usr/bin/env bash
# octo adapters — symlink skills/agents into the dirs other harnesses read.
# Idempotent; --uninstall removes exactly what install created; never
# overwrites a non-symlink.
set -euo pipefail
PLUGIN="$(cd "$(dirname "$0")/.." && pwd)"
MODE=${1:-install}

link() {  # link <target> <linkpath>
  local target=$1 linkpath=$2
  if [ -L "$linkpath" ]; then
    [ "$(readlink "$linkpath")" = "$target" ] && { echo "ok      $linkpath"; return; }
    echo "skip    $linkpath (symlink to elsewhere)"; return
  fi
  [ -e "$linkpath" ] && { echo "skip    $linkpath (exists, not a symlink)"; return; }
  if ln -s "$target" "$linkpath" 2>/dev/null; then echo "linked  $linkpath"; else echo "FAILED  $linkpath (ln error — continuing)"; fi
}

unlink_ours() {  # unlink_ours <linkpath>
  if [ -L "$1" ] && case "$(readlink "$1")" in "$PLUGIN"/*) true;; *) false;; esac; then
    if rm "$1" 2>/dev/null; then echo "removed $1"; else echo "FAILED  $1 (rm error — continuing)"; fi
  fi
}

mkdir -p "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.claude/agents"

for d in "$PLUGIN"/skills/*/; do
  name=$(basename "$d")
  if [ "$MODE" = "--uninstall" ]; then
    unlink_ours "$HOME/.claude/skills/octo-$name"
    unlink_ours "$HOME/.agents/skills/octo-$name"
  else
    link "${d%/}" "$HOME/.claude/skills/octo-$name"
    link "${d%/}" "$HOME/.agents/skills/octo-$name"
  fi
done

for f in "$PLUGIN"/agents/*.md; do
  base=$(basename "$f")
  if [ "$MODE" = "--uninstall" ]; then
    unlink_ours "$HOME/.claude/agents/$base"
  else
    link "$f" "$HOME/.claude/agents/$base"
  fi
done
