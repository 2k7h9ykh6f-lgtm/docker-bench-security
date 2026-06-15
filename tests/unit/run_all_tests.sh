#!/bin/sh
# Run all unit tests
# Usage: sh tests/unit/run_all_tests.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../.." || exit 1

printf "=====================================\n"
printf "Docker Bench Security - Unit Tests\n"
printf "=====================================\n\n"

TOTAL_PASS=0
TOTAL_FAIL=0

# Run exit code tests
printf "\n>>> Running exit code strategy tests...\n"
printf "-------------------------------------\n"
if sh tests/unit/test_exit_code.sh; then
  TOTAL_PASS=$((TOTAL_PASS + 1))
else
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
fi

# Run output counter tests
printf "\n>>> Running output counter tests...\n"
printf "-------------------------------------\n"
if sh tests/unit/test_output_counters.sh; then
  TOTAL_PASS=$((TOTAL_PASS + 1))
else
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
fi

# Summary
printf "\n=====================================\n"
printf "Overall Test Suite Results\n"
printf "=====================================\n"
printf "Test suites passed: %d\n" "$TOTAL_PASS"
printf "Test suites failed: %d\n" "$TOTAL_FAIL"
printf "=====================================\n"

if [ "$TOTAL_FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
