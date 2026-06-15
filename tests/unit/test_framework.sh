#!/bin/bash
# --------------------------------------------------------------------------------------------
# Lightweight test framework for runtime_lib.sh
#
# Usage: source this file in test scripts, then use assert_* functions.
# Call test_summary at the end to report results and exit with appropriate code.
# --------------------------------------------------------------------------------------------

# Test state
_TEST_PASS=0
_TEST_FAIL=0
_TEST_TOTAL=0
_TEST_CURRENT_GROUP=""
_TEST_FAILURES=""

# Colors (disable if not a terminal)
if [ -t 1 ]; then
  _TRED='\033[0;31m'
  _TGRN='\033[0;32m'
  _TYLW='\033[0;33m'
  _TRST='\033[0m'
else
  _TRED=''
  _TGRN=''
  _TYLW=''
  _TRST=''
fi

# describe(name) - Mark the start of a test group
describe() {
  _TEST_CURRENT_GROUP="$1"
  printf "\n${_TYLW}=== %s ===${_TRST}\n" "$1"
}

# _record_pass(msg)
_record_pass() {
  _TEST_PASS=$((_TEST_PASS + 1))
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  printf "  ${_TGRN}PASS${_TRST} %s\n" "$1"
}

# _record_fail(msg)
_record_fail() {
  _TEST_FAIL=$((_TEST_FAIL + 1))
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  printf "  ${_TRED}FAIL${_TRST} %s\n" "$1"
  _TEST_FAILURES="${_TEST_FAILURES}\n  - ${_TEST_CURRENT_GROUP}: $1"
}

# assert_eq(expected, actual, msg)
assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [ "$expected" = "$actual" ]; then
    _record_pass "$msg"
  else
    _record_fail "$msg (expected='$expected', actual='$actual')"
  fi
}

# assert_empty(val, msg)
assert_empty() {
  local val="$1" msg="$2"
  if [ -z "$val" ]; then
    _record_pass "$msg"
  else
    _record_fail "$msg (expected empty, got='$val')"
  fi
}

# assert_not_empty(val, msg)
assert_not_empty() {
  local val="$1" msg="$2"
  if [ -n "$val" ]; then
    _record_pass "$msg"
  else
    _record_fail "$msg (expected non-empty, got empty)"
  fi
}

# assert_contains(haystack, needle, msg)
assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if echo "$haystack" | grep -q "$needle" 2>/dev/null; then
    _record_pass "$msg"
  else
    _record_fail "$msg (expected to contain '$needle' in '$haystack')"
  fi
}

# assert_return_code(expected, actual, msg)
assert_return_code() {
  local expected="$1" actual="$2" msg="$3"
  if [ "$expected" -eq "$actual" ] 2>/dev/null; then
    _record_pass "$msg"
  else
    _record_fail "$msg (expected rc=$expected, got rc=$actual)"
  fi
}

# test_summary() - Print summary and exit with appropriate code
test_summary() {
  printf "\n"
  if [ $_TEST_FAIL -eq 0 ]; then
    printf "${_TGRN}All %d tests passed.${_TRST}\n" "$_TEST_TOTAL"
    exit 0
  else
    printf "${_TRED}%d of %d tests FAILED:${_TRST}%b\n" "$_TEST_FAIL" "$_TEST_TOTAL" "$_TEST_FAILURES"
    exit 1
  fi
}
