#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
H=$(pwd)/hooks/auto-format.sh

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
# fake ruff that rewrites the file so we can observe it ran
cat > "$TMP/bin/ruff" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "format" ] && echo "formatted" > "$2"
EOF
chmod +x "$TMP/bin/ruff"

cd "$TMP"; touch pyproject.toml; echo "x=1" > f.py
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/f.py"}}' "$TMP" | PATH="$TMP/bin:$PATH" bash "$H"
grep -q formatted f.py || { echo "ruff not invoked"; exit 1; }

# no formatter config -> untouched, still exit 0
echo "y=2" > g.py; rm pyproject.toml
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/g.py"}}' "$TMP" | PATH="$TMP/bin:$PATH" bash "$H"
grep -q "y=2" g.py || { echo "should not have formatted"; exit 1; }

# formatter binary absent -> silent skip, exit 0
touch pyproject.toml; echo "z=3" > h.py
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/h.py"}}' "$TMP" | PATH="/usr/bin:/bin" bash "$H"
grep -q "z=3" h.py || { echo "should have skipped"; exit 1; }

# monorepo: config only in subpackage dir, not in cwd -> must still format
mkdir -p "$TMP/mono/services/api"
touch "$TMP/mono/services/api/pyproject.toml"
echo "a=1" > "$TMP/mono/services/api/app.py"
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/mono/services/api/app.py"}}' "$TMP" \
  | (cd "$TMP/mono" && PATH="$TMP/bin:$PATH" bash "$H")
grep -q formatted "$TMP/mono/services/api/app.py" || { echo "monorepo: ruff not invoked"; exit 1; }
