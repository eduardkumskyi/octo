#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'EOF'
import os, re, sys, glob

def fm(path):
    text = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    assert m, f"{path}: no frontmatter"
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"')
    return meta, m.group(2)

skills = glob.glob("skills/*/SKILL.md")
agents = glob.glob("agents/*.md")
if not skills and not agents:
    print("WARN: no artifacts yet"); sys.exit(0)

for p in skills:
    meta, body = fm(p)
    d = os.path.basename(os.path.dirname(p))
    assert meta.get("name") == d, f"{p}: name != dir ({meta.get('name')} vs {d})"
    assert meta.get("description"), f"{p}: empty description"

for p in agents:
    meta, body = fm(p)
    base = os.path.splitext(os.path.basename(p))[0]
    assert meta.get("name") == base, f"{p}: name != filename"
    assert meta.get("description"), f"{p}: empty description"
    assert meta.get("model"), f"{p}: missing model"
    assert "CLAUDE.md" in body, f"{p}: missing CLAUDE.md preamble"
print(f"validated {len(skills)} skills, {len(agents)} agents")
EOF
