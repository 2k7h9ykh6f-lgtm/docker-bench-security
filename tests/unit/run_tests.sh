#!/bin/bash
# --------------------------------------------------------------------------------------------
# Test runner: executes all test_runtime_*.sh files and reports aggregate results.
# --------------------------------------------------------------------------------------------
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
FAILED_NAMES=""

printf "Running runtime discovery tests...\n"
printf "========================================\n"

for test_file in "$SCRIPT_DIR"/test_runtime_*.sh; do
  if [ ! -f "$test_file" ]; then
    continue
  fi

  TOTAL_FILES=$((TOTAL_FILES + 1))
  test_name="$(basename "$test_file")"
  printf "\n>>> %s\n" "$test_name"

  if bash "$test_file"; then
    PASSED_FILES=$((PASSED_FILES + 1))
  else
    FAILED_FILES=$((FAILED_FILES + 1))
    FAILED_NAMES="$FAILED_NAMES\n  - $test_name"
  fi
done

printf "\n========================================\n"
if [ $FAILED_FILES -eq 0 ]; then
  printf "All %d test files passed.\n" "$TOTAL_FILES"
  exit 0
else
  printf "%d of %d test files FAILED:%b\n" "$FAILED_FILES" "$TOTAL_FILES" "$FAILED_NAMES"
  exit 1
fi
