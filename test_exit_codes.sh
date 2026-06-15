#!/bin/bash
# test_exit_codes.sh - Unit tests for per-type counters and exit code strategy
# Run from the repository root: bash test_exit_codes.sh
# No Docker required.

set +u

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Minimal environment to source output_lib.sh
logger="/dev/null"
nocolor="nocolor"

# Initialize counters (normally done in docker-bench-security.sh)
totalChecks=0
currentScore=0
passCount=0
warnCount=0
infoCount=0
noteCount=0

# Source the library under test
. ./functions/output_lib.sh

# ---- Helpers ----

reset_counters() {
  totalChecks=0
  currentScore=0
  passCount=0
  warnCount=0
  infoCount=0
  noteCount=0
}

assert_eq() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "  PASS: %s\n" "$description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  FAIL: %s (expected=%s, actual=%s)\n" "$description" "$expected" "$actual"
  fi
}

# ---- Test Cases ----

# Test 1: No failures (all pass results)
test_no_failures() {
  printf "Test 1: No failures - all PASS\n"
  reset_counters
  pass -s "check 1" >/dev/null 2>&1
  pass -s "check 2" >/dev/null 2>&1
  pass -c "check 3" >/dev/null 2>&1
  assert_eq "totalChecks is 3"  "3" "$totalChecks"
  assert_eq "currentScore is 2" "2" "$currentScore"
  assert_eq "passCount is 3"    "3" "$passCount"
  assert_eq "warnCount is 0"    "0" "$warnCount"
  assert_eq "infoCount is 0"    "0" "$infoCount"
  assert_eq "noteCount is 0"    "0" "$noteCount"

  assert_eq "exit(default)=0" "0" "$(get_exit_code '')"
  assert_eq "exit(warn)=0"    "0" "$(get_exit_code 'warn')"
  assert_eq "exit(score)=0"   "0" "$(get_exit_code 'score')"
}

# Test 2: Has WARN results (more warns than passes, negative score)
test_has_warn() {
  printf "Test 2: Has WARN results\n"
  reset_counters
  pass -s "check 1" >/dev/null 2>&1
  warn -s "check 2" >/dev/null 2>&1
  warn -s "check 3" >/dev/null 2>&1
  assert_eq "totalChecks is 3"   "3" "$totalChecks"
  assert_eq "currentScore is -1" "-1" "$currentScore"
  assert_eq "passCount is 1"     "1" "$passCount"
  assert_eq "warnCount is 2"     "2" "$warnCount"

  assert_eq "exit(default)=0" "0" "$(get_exit_code '')"
  assert_eq "exit(warn)=1"    "1" "$(get_exit_code 'warn')"
  assert_eq "exit(score)=1"   "1" "$(get_exit_code 'score')"
}

# Test 3: Mixed results (WARN balanced by PASS, net positive score)
test_mixed_results_positive_score() {
  printf "Test 3: Mixed results - net positive score\n"
  reset_counters
  pass -s "check 1" >/dev/null 2>&1
  pass -s "check 2" >/dev/null 2>&1
  pass -s "check 3" >/dev/null 2>&1
  warn -s "check 4" >/dev/null 2>&1
  info -c "check 5" >/dev/null 2>&1
  note -c "check 6" >/dev/null 2>&1
  assert_eq "totalChecks is 6"  "6" "$totalChecks"
  assert_eq "currentScore is 2" "2" "$currentScore"
  assert_eq "passCount is 3"    "3" "$passCount"
  assert_eq "warnCount is 1"    "1" "$warnCount"
  assert_eq "infoCount is 1"    "1" "$infoCount"
  assert_eq "noteCount is 1"    "1" "$noteCount"

  assert_eq "exit(default)=0" "0" "$(get_exit_code '')"
  assert_eq "exit(warn)=1"    "1" "$(get_exit_code 'warn')"
  assert_eq "exit(score)=0"   "0" "$(get_exit_code 'score')"
}

# Test 4: Strict CI mode - single warn among many passes
test_strict_ci_mode() {
  printf "Test 4: Strict CI mode - single warn triggers failure\n"
  reset_counters
  pass -s "check 1" >/dev/null 2>&1
  pass -s "check 2" >/dev/null 2>&1
  pass -s "check 3" >/dev/null 2>&1
  pass -s "check 4" >/dev/null 2>&1
  pass -s "check 5" >/dev/null 2>&1
  warn -s "check 6" >/dev/null 2>&1
  assert_eq "passCount is 5"    "5" "$passCount"
  assert_eq "warnCount is 1"    "1" "$warnCount"
  assert_eq "currentScore is 4" "4" "$currentScore"

  assert_eq "exit(warn)=1 (strict gate)"  "1" "$(get_exit_code 'warn')"
  assert_eq "exit(score)=0 (lenient gate)" "0" "$(get_exit_code 'score')"
}

# Test 5: Bare calls (no flags) do not affect counters
test_bare_calls_no_counting() {
  printf "Test 5: Bare pass/warn/info calls do not increment counters\n"
  reset_counters
  pass "detail line" >/dev/null 2>&1
  warn "detail line" >/dev/null 2>&1
  info "detail line" >/dev/null 2>&1
  note "detail line" >/dev/null 2>&1
  assert_eq "totalChecks is 0" "0" "$totalChecks"
  assert_eq "passCount is 0"   "0" "$passCount"
  assert_eq "warnCount is 0"   "0" "$warnCount"
  assert_eq "infoCount is 0"   "0" "$infoCount"
  assert_eq "noteCount is 0"   "0" "$noteCount"
}

# Test 6: Unknown strategy defaults to exit 0
test_unknown_strategy() {
  printf "Test 6: Unknown strategy defaults to exit 0\n"
  reset_counters
  warn -s "check 1" >/dev/null 2>&1
  assert_eq "exit(unknown)=0" "0" "$(get_exit_code 'bogus')"
  assert_eq "exit(empty)=0"   "0" "$(get_exit_code '')"
}

# ---- Run all tests ----
test_no_failures
test_has_warn
test_mixed_results_positive_score
test_strict_ci_mode
test_bare_calls_no_counting
test_unknown_strategy

# ---- Summary ----
printf "\n================================\n"
printf "Tests run: %s  Passed: %s  Failed: %s\n" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
