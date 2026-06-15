#!/bin/bash
# Runs shellcheck against all .sh files in the repository.
# Respects the project .shellcheckrc at repo root.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "SKIP: shellcheck not found — install it to enable static analysis"
  exit 0
fi

pass=0
fail=0
failed_files=""

for f in \
  docker-bench-security.sh \
  functions/*.sh \
  tests/*.sh; do
  [ -f "$f" ] || continue
  if shellcheck "$f"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    failed_files="$failed_files $f"
  fi
done

echo ""
echo "shellcheck: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  echo "failures:$failed_files"
  exit 1
fi
