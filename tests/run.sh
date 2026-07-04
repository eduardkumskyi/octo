#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
for t in tests/test_*.sh; do
  if bash "$t" </dev/null; then echo "PASS $t"; else echo "FAIL $t"; fail=1; fi
done
exit $fail
