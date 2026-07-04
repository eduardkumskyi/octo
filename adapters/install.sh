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
  ln -s "$target" "$linkpath" && echo "linked  $linkpath"
}

unlink_ours() {  # unlink_ours <linkpath>
  if [ -L "$1" ] && case "$(readlink "$1")" in "$PLUGIN"/*) true;; *) false;; esac; then
    rm "$1" && echo "removed $1"
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
