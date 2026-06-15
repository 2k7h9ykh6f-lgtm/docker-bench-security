#!/bin/sh
# Test suite for exit code strategies
# Run: sh tests/unit/test_exit_code.sh

PASS=0
FAIL=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

assert_exit_code() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$expected" -eq "$actual" ]; then
    printf "${GREEN}[PASS]${NC} %s (expected=%d, got=%d)\n" "$test_name" "$expected" "$actual"
    PASS=$((PASS + 1))
  else
    printf "${RED}[FAIL]${NC} %s (expected=%d, got=%d)\n" "$test_name" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

# Source the helper library to get compute_exit_code
. functions/helper_lib.sh

printf "Testing exit code strategies...\n\n"

# Test 1: none strategy - always exit 0
compute_exit_code "none" 0 0 10 0
assert_exit_code "none: no warnings" 0 $?

compute_exit_code "none" 5 3 -2 0
assert_exit_code "none: with warnings and negative score" 0 $?

# Test 2: warn strategy
compute_exit_code "warn" 0 0 10 0
assert_exit_code "warn: no warnings" 0 $?

compute_exit_code "warn" 1 0 10 0
assert_exit_code "warn: one warning" 1 $?

compute_exit_code "warn" 5 0 10 0
assert_exit_code "warn: multiple warnings" 1 $?

compute_exit_code "warn" 0 5 10 0
assert_exit_code "warn: info but no warnings" 0 $?

# Test 3: info strategy
compute_exit_code "info" 0 0 10 0
assert_exit_code "info: no warnings or info" 0 $?

compute_exit_code "info" 1 0 10 0
assert_exit_code "info: one warning" 2 $?

compute_exit_code "info" 0 1 10 0
assert_exit_code "info: one info" 1 $?

compute_exit_code "info" 5 3 10 0
assert_exit_code "info: warnings and info" 2 $?

compute_exit_code "info" 0 5 10 0
assert_exit_code "info: info but no warnings" 1 $?

# Test 4: score strategy
compute_exit_code "score" 0 0 10 0
assert_exit_code "score: positive score, threshold 0" 0 $?

compute_exit_code "score" 0 0 0 0
assert_exit_code "score: zero score, threshold 0" 0 $?

compute_exit_code "score" 0 0 -1 0
assert_exit_code "score: negative score, threshold 0" 1 $?

compute_exit_code "score" 0 0 -5 0
assert_exit_code "score: very negative score, threshold 0" 1 $?

compute_exit_code "score" 0 0 5 10
assert_exit_code "score: score 5, threshold 10" 1 $?

compute_exit_code "score" 0 0 10 10
assert_exit_code "score: score 10, threshold 10" 0 $?

compute_exit_code "score" 0 0 15 10
assert_exit_code "score: score 15, threshold 10" 0 $?

compute_exit_code "score" 0 0 -3 -5
assert_exit_code "score: score -3, threshold -5" 0 $?

compute_exit_code "score" 0 0 -6 -5
assert_exit_code "score: score -6, threshold -5" 1 $?

# Test 5: invalid strategy
compute_exit_code "invalid" 5 3 10 0 2>/dev/null
assert_exit_code "invalid: unknown strategy falls back to 0" 0 $?

# Summary
printf "\n========================================\n"
printf "Test Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
printf "========================================\n"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
