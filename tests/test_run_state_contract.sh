#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'EOF'
import json, sys, pathlib, re

FIXTURE_DIR = pathlib.Path("tests/fixtures/run")
STATE_FILE  = FIXTURE_DIR / "state.json"
EVENTS_FILE = FIXTURE_DIR / "events.jsonl"
SKILL_FILES = [
    pathlib.Path("skills/build/SKILL.md"),
    pathlib.Path("skills/studio/SKILL.md"),
]
REQUIRED_STATE_KEYS   = {"mission", "mode", "phase", "milestones", "lanes", "iteration", "updated"}
VALID_MILESTONE_STATUS = {"PENDING", "IN_PROGRESS", "VERIFIED", "PARKED"}
REQUIRED_MILESTONE_KEYS = {"id", "title", "status"}
REQUIRED_LANE_KEYS      = {"agent", "task", "started"}
REQUIRED_EVENT_TYPES    = {"milestone", "step", "decision", "finding", "assumption"}

errors = []

# (a) parse state.json as valid JSON
try:
    state = json.loads(STATE_FILE.read_text())
except Exception as e:
    errors.append(f"state.json not valid JSON: {e}")
    state = {}

# parse every line of events.jsonl as valid JSON
events = []
for i, line in enumerate(EVENTS_FILE.read_text().splitlines(), 1):
    line = line.strip()
    if not line:
        continue
    try:
        events.append(json.loads(line))
    except Exception as e:
        errors.append(f"events.jsonl line {i} not valid JSON: {e}")

# (b) state.json required keys
missing_keys = REQUIRED_STATE_KEYS - state.keys()
if missing_keys:
    errors.append(f"state.json missing keys: {sorted(missing_keys)}")

for ms in state.get("milestones", []):
    mk = set(ms.keys())
    if not REQUIRED_MILESTONE_KEYS.issubset(mk):
        errors.append(f"milestone {ms} missing keys {REQUIRED_MILESTONE_KEYS - mk}")
    if ms.get("status") not in VALID_MILESTONE_STATUS:
        errors.append(f"milestone {ms.get('id')} has invalid status: {ms.get('status')!r}")

for lane in state.get("lanes", []):
    lk = set(lane.keys())
    if not REQUIRED_LANE_KEYS.issubset(lk):
        errors.append(f"lane {lane} missing keys {REQUIRED_LANE_KEYS - lk}")

# (c) events cover required type set
seen_types = {ev.get("type") for ev in events}
missing_types = REQUIRED_EVENT_TYPES - seen_types
if missing_types:
    errors.append(f"events.jsonl missing event types: {sorted(missing_types)}")

# (d) each event type that the fixtures pin appears in at least one skill
skill_text = "\n".join(p.read_text() for p in SKILL_FILES)
pinned_types = REQUIRED_EVENT_TYPES & seen_types
for etype in sorted(pinned_types):
    # match loosely: the type name appears with "type" nearby (within 30 chars)
    pattern = re.compile(r'type.{0,30}' + re.escape(etype) + r'|' + re.escape(etype) + r'.{0,30}type')
    if not pattern.search(skill_text):
        errors.append(f'event type "{etype}" in fixtures but not found near "type" in any skill file')

if errors:
    for e in errors:
        print("FAIL:", e)
    sys.exit(1)

print(f"OK: state.json valid, {len(events)} events, all {len(pinned_types)} fixture types confirmed in skills")
EOF
