#!/bin/sh
# Test suite for output counters
# Run: sh tests/unit/test_output_counters.sh

PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$expected" = "$actual" ]; then
    printf "${GREEN}[PASS]${NC} %s (expected=%s, got=%s)\n" "$test_name" "$expected" "$actual"
    PASS=$((PASS + 1))
  else
    printf "${RED}[FAIL]${NC} %s (expected=%s, got=%s)\n" "$test_name" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

# Setup minimal environment for output_lib.sh
nocolor="nocolor"  # Disable colors for cleaner test output
logger="/dev/null"  # Don't write to log file
totalChecks=0
currentScore=0
passCount=0
warnCount=0
infoCount=0
noteCount=0

# Source the output library
. functions/output_lib.sh

printf "Testing output counters...\n\n"

# Test 1: pass -s increments passCount and currentScore
pass -s "test pass scored"
assert_eq "pass -s: passCount" 1 "$passCount"
assert_eq "pass -s: currentScore" 1 "$currentScore"
assert_eq "pass -s: totalChecks" 1 "$totalChecks"

# Test 2: pass -c increments passCount but not currentScore
pass -c "test pass count"
assert_eq "pass -c: passCount" 2 "$passCount"
assert_eq "pass -c: currentScore" 1 "$currentScore"
assert_eq "pass -c: totalChecks" 2 "$totalChecks"

# Test 3: warn -s increments warnCount and decrements currentScore
warn -s "test warn scored"
assert_eq "warn -s: warnCount" 1 "$warnCount"
assert_eq "warn -s: currentScore" 0 "$currentScore"
assert_eq "warn -s: totalChecks" 3 "$totalChecks"

# Test 4: info -c increments infoCount
info -c "test info count"
assert_eq "info -c: infoCount" 1 "$infoCount"
assert_eq "info -c: totalChecks" 4 "$totalChecks"

# Test 5: note -c increments noteCount
note -c "test note count"
assert_eq "note -c: noteCount" 1 "$noteCount"
assert_eq "note -c: totalChecks" 5 "$totalChecks"

# Test 6: Multiple operations
pass -s "another pass"
pass -s "yet another pass"
warn -s "another warn"
info -c "another info"

assert_eq "multiple: passCount" 4 "$passCount"
assert_eq "multiple: warnCount" 2 "$warnCount"
assert_eq "multiple: infoCount" 2 "$infoCount"
assert_eq "multiple: noteCount" 1 "$noteCount"
assert_eq "multiple: currentScore" 1 "$currentScore"  # 3 pass -s, 2 warn -s = +3 -2 = +1
assert_eq "multiple: totalChecks" 9 "$totalChecks"

# Summary
printf "\n========================================\n"
printf "Test Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
printf "========================================\n"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
