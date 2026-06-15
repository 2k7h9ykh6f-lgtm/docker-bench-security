#!/bin/bash
# --------------------------------------------------------------------------------------------
# test_skip_rules.sh - Validation tests for the centralized skip rule parser
#
# Self-contained: creates a temporary mock project tree with stub test files
# and a stub functions_lib.sh, then exercises parse_skip_rules() under
# various scenarios.
#
# Run:  bash tests/test_skip_rules.sh
# Exit: 0 if all tests pass, 1 otherwise.
# --------------------------------------------------------------------------------------------

set -u

PASS=0
FAIL=0
TESTS_RUN=0
FAILURES=""

# Temp file for stderr capture
STDERR_FILE=""

# --------------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------------
pass_test() {
  PASS=$((PASS + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "  PASS: %s\n" "$1"
}

fail_test() {
  FAIL=$((FAIL + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "  FAIL: %s\n" "$1"
  FAILURES="${FAILURES}
  - $1: $2"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass_test "$desc"
  else
    fail_test "$desc" "expected='$expected', actual='$actual'"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) pass_test "$desc" ;;
    *) fail_test "$desc" "expected to contain '$needle' in '$haystack'" ;;
  esac
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) fail_test "$desc" "expected NOT to contain '$needle' in '$haystack'" ;;
    *) pass_test "$desc" ;;
  esac
}

assert_return() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass_test "$desc"
  else
    fail_test "$desc" "expected return=$expected, got return=$actual"
  fi
}

# Run parse_skip_rules in the CURRENT shell, capturing stderr to STDERR_FILE
run_parse() {
  parse_skip_rules "$@" 2>"$STDERR_FILE"
}

get_stderr() {
  cat "$STDERR_FILE"
}

# --------------------------------------------------------------------------------------------
# Set up mock project tree
# --------------------------------------------------------------------------------------------
MOCK_ROOT=$(mktemp -d)
STDERR_FILE=$(mktemp)
trap 'rm -rf "$MOCK_ROOT" "$STDERR_FILE"' EXIT

LIBEXEC="$MOCK_ROOT"
export LIBEXEC

mkdir -p "$MOCK_ROOT/tests"
mkdir -p "$MOCK_ROOT/functions"

# Stub test files with check functions (using func() { format like real project)
cat > "$MOCK_ROOT/tests/1_host_configuration.sh" <<'STUB'
check_1() { :; }
check_1_1() { :; }
check_1_1_1() { :; }
check_1_1_2() { :; }
check_1_2() { :; }
check_1_2_1() { :; }
check_1_2_2() { :; }
check_1_end() { :; }
STUB

cat > "$MOCK_ROOT/tests/2_docker_daemon_configuration.sh" <<'STUB'
check_2() { :; }
check_2_1() { :; }
check_2_2() { :; }
check_2_3() { :; }
check_2_8() { :; }
check_2_end() { :; }
STUB

cat > "$MOCK_ROOT/tests/4_container_images.sh" <<'STUB'
check_4() { :; }
check_4_1() { :; }
check_4_5() { :; }
check_4_end() { :; }
STUB

cat > "$MOCK_ROOT/tests/5_container_runtime.sh" <<'STUB'
check_5() { :; }
check_running_containers() { :; }
check_5_1() { :; }
check_5_32() { :; }
check_5_end() { :; }
STUB

cat > "$MOCK_ROOT/tests/99_community_checks.sh" <<'STUB'
check_c() { :; }
check_c_1() { :; }
check_c_5_3_1() { :; }
check_c_end() { :; }
STUB

# Stub functions_lib.sh with group functions
cat > "$MOCK_ROOT/functions/functions_lib.sh" <<'STUB'
host_configuration() {
  check_1
  check_1_1
  check_1_1_1
}

docker_daemon_configuration() {
  check_2
  check_2_1
}

container_images() {
  check_4
  check_4_1
}

cis() {
  host_configuration
  docker_daemon_configuration
  container_images
}

community_checks() {
  check_c
  check_c_1
}

all() {
  cis
  community_checks
}
STUB

# Source the library under test
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$SCRIPT_DIR/functions/skip_lib.sh"

# --------------------------------------------------------------------------------------------
# Tests
# --------------------------------------------------------------------------------------------
printf "\n=== Test Suite: skip rule parser ===\n\n"

# ---- Test 1: Valid CLI skip ----
printf "Test 1: Valid CLI skip\n"
run_parse "" "check_2_2,check_4_5"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0 for valid rules" "0" "$rc"
assert_eq "SKIP_EXCLUDE_LIST has both checks" "check_2_2 check_4_5" "$SKIP_EXCLUDE_LIST"
assert_eq "no errors" "0" "$SKIP_ERRORS"
assert_eq "no warnings" "0" "$SKIP_WARNINGS"
printf "\n"

# ---- Test 2: Unknown check ID ----
printf "Test 2: Unknown check ID\n"
run_parse "" "check_99_99"
rc=$?
stderr=$(get_stderr)
assert_return "returns 1 for unknown ID" "1" "$rc"
assert_eq "SKIP_EXCLUDE_LIST is empty" "" "$SKIP_EXCLUDE_LIST"
assert_eq "one error recorded" "1" "$SKIP_ERRORS"
assert_contains "error message mentions the bad ID" "check_99_99" "$stderr"
assert_contains "error message says 'unknown'" "unknown" "$stderr"
printf "\n"

# ---- Test 3: Duplicate check IDs ----
printf "Test 3: Duplicate check IDs\n"
run_parse "" "check_2_2,check_2_2,check_4_1"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0 (dedup is warning only)" "0" "$rc"
assert_eq "deduplicated list" "check_2_2 check_4_1" "$SKIP_EXCLUDE_LIST"
assert_eq "no errors" "0" "$SKIP_ERRORS"
assert_eq "one warning for duplicate" "1" "$SKIP_WARNINGS"
assert_contains "warning mentions 'duplicate'" "duplicate" "$stderr"
printf "\n"

# ---- Test 4: Empty entries in CLI ----
printf "Test 4: Empty entries in CLI\n"
run_parse "" "check_2_2,,check_4_1"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "valid entries kept" "check_2_2 check_4_1" "$SKIP_EXCLUDE_LIST"
assert_eq "one warning for empty entry" "1" "$SKIP_WARNINGS"
assert_contains "warning mentions 'empty'" "empty" "$stderr"
printf "\n"

# ---- Test 5: Config file with valid IDs ----
printf "Test 5: Config file with valid IDs\n"
cfg="$MOCK_ROOT/skip.conf"
cat > "$cfg" <<'EOF'
# Skip these checks
check_2_1
check_4_5

# End of config
EOF
run_parse "$cfg" ""
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "config entries parsed" "check_2_1 check_4_5" "$SKIP_EXCLUDE_LIST"
assert_eq "no errors" "0" "$SKIP_ERRORS"
assert_eq "no warnings" "0" "$SKIP_WARNINGS"
printf "\n"

# ---- Test 6: Config file with unknown ID ----
printf "Test 6: Config file with unknown ID\n"
cfg="$MOCK_ROOT/skip_bad.conf"
cat > "$cfg" <<'EOF'
check_2_1
check_99_99
check_4_1
EOF
run_parse "$cfg" ""
rc=$?
stderr=$(get_stderr)
assert_return "returns 1" "1" "$rc"
assert_eq "valid entries kept, bad one excluded" "check_2_1 check_4_1" "$SKIP_EXCLUDE_LIST"
assert_eq "one error" "1" "$SKIP_ERRORS"
assert_contains "error mentions config source" "config:" "$stderr"
assert_contains "error mentions bad ID" "check_99_99" "$stderr"
printf "\n"

# ---- Test 7: Mixed sources (config + CLI) ----
printf "Test 7: Mixed sources (config + CLI)\n"
cfg="$MOCK_ROOT/skip_mix.conf"
cat > "$cfg" <<'EOF'
check_2_1
EOF
run_parse "$cfg" "check_4_5,check_5_1"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_contains "config entry present" "check_2_1" "$SKIP_EXCLUDE_LIST"
assert_contains "CLI entry 1 present" "check_4_5" "$SKIP_EXCLUDE_LIST"
assert_contains "CLI entry 2 present" "check_5_1" "$SKIP_EXCLUDE_LIST"
assert_eq "no errors" "0" "$SKIP_ERRORS"
printf "\n"

# ---- Test 8: Duplicate across sources ----
printf "Test 8: Duplicate across sources\n"
cfg="$MOCK_ROOT/skip_dup.conf"
cat > "$cfg" <<'EOF'
check_2_2
EOF
run_parse "$cfg" "check_2_2"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "only one copy kept" "check_2_2" "$SKIP_EXCLUDE_LIST"
assert_eq "one warning for cross-source duplicate" "1" "$SKIP_WARNINGS"
assert_contains "warning mentions 'duplicate'" "duplicate" "$stderr"
printf "\n"

# ---- Test 9: Dot-notation normalization ----
printf "Test 9: Dot-notation normalization\n"
run_parse "" "2.2,4.5"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "dot notation normalized" "check_2_2 check_4_5" "$SKIP_EXCLUDE_LIST"
assert_eq "no errors" "0" "$SKIP_ERRORS"
printf "\n"

# ---- Test 10: Community check dot notation ----
printf "Test 10: Community check dot notation\n"
run_parse "" "C.5.3.1"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "C.5.3.1 -> check_c_5_3_1" "check_c_5_3_1" "$SKIP_EXCLUDE_LIST"
printf "\n"

# ---- Test 11: No rules at all ----
printf "Test 11: No skip rules provided\n"
run_parse "" ""
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "SKIP_EXCLUDE_LIST is empty" "" "$SKIP_EXCLUDE_LIST"
assert_eq "no errors" "0" "$SKIP_ERRORS"
assert_eq "no warnings" "0" "$SKIP_WARNINGS"
printf "\n"

# ---- Test 12: Group names are valid ----
printf "Test 12: Group/section function names are valid\n"
run_parse "" "host_configuration,docker_daemon_configuration"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "group names accepted" "host_configuration docker_daemon_configuration" "$SKIP_EXCLUDE_LIST"
printf "\n"

# ---- Test 13: Config file not found (non-fatal) ----
printf "Test 13: Config file not found\n"
run_parse "/nonexistent/path/skip.conf" "check_2_2"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0 (missing file is not fatal)" "0" "$rc"
assert_eq "CLI entry still parsed" "check_2_2" "$SKIP_EXCLUDE_LIST"
printf "\n"

# ---- Test 14: build_skip_regex ----
printf "Test 14: build_skip_regex\n"
SKIP_EXCLUDE_LIST="check_2_2 check_4_5"
build_skip_regex
assert_eq "regex built correctly" "^check_2_2$|^check_4_5$" "$SKIP_REGEX"
printf "\n"

# ---- Test 15: build_skip_regex empty ----
printf "Test 15: build_skip_regex with empty list\n"
SKIP_EXCLUDE_LIST=""
build_skip_regex
assert_eq "regex is empty" "" "$SKIP_REGEX"
printf "\n"

# ---- Test 16: Regex actually matches ----
printf "Test 16: Regex matching correctness\n"
SKIP_EXCLUDE_LIST="check_2_2 check_4_5 host_configuration"
build_skip_regex
echo "check_2_2" | grep -E "$SKIP_REGEX" >/dev/null 2>&1
assert_return "check_2_2 matches" "0" "$?"
echo "check_2_3" | grep -E "$SKIP_REGEX" >/dev/null 2>&1
assert_return "check_2_3 does NOT match" "1" "$?"
echo "host_configuration" | grep -E "$SKIP_REGEX" >/dev/null 2>&1
assert_return "host_configuration matches" "0" "$?"
echo "check_2_22" | grep -E "$SKIP_REGEX" >/dev/null 2>&1
assert_return "check_2_22 does NOT match (anchored)" "1" "$?"
printf "\n"

# ---- Test 17: Config file with blank lines and inline comments ----
printf "Test 17: Config file formatting edge cases\n"
cfg="$MOCK_ROOT/skip_fmt.conf"
cat > "$cfg" <<'EOF'
  check_2_1   # this is a comment

# full line comment
  check_4_5
EOF
run_parse "$cfg" ""
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "trimmed entries parsed" "check_2_1 check_4_5" "$SKIP_EXCLUDE_LIST"
printf "\n"

# ---- Test 18: DBS_SKIP environment variable ----
printf "Test 18: DBS_SKIP environment variable\n"
DBS_SKIP="check_5_1,check_5_32"
run_parse "" ""
rc=$?
stderr=$(get_stderr)
unset DBS_SKIP
assert_return "returns 0" "0" "$rc"
assert_eq "env entries parsed" "check_5_1 check_5_32" "$SKIP_EXCLUDE_LIST"
printf "\n"

# ---- Test 19: Multiple unknown IDs all reported ----
printf "Test 19: Multiple unknown IDs all reported\n"
run_parse "" "check_99_1,check_99_2,check_2_1"
rc=$?
stderr=$(get_stderr)
assert_return "returns 1" "1" "$rc"
assert_eq "two errors" "2" "$SKIP_ERRORS"
assert_eq "valid entry still kept" "check_2_1" "$SKIP_EXCLUDE_LIST"
assert_contains "first bad ID reported" "check_99_1" "$stderr"
assert_contains "second bad ID reported" "check_99_2" "$stderr"
printf "\n"

# ---- Test 20: Whitespace-only entry treated as empty ----
printf "Test 20: Whitespace-only entry\n"
run_parse "" "check_2_1,   ,check_4_1"
rc=$?
stderr=$(get_stderr)
assert_return "returns 0" "0" "$rc"
assert_eq "valid entries kept" "check_2_1 check_4_1" "$SKIP_EXCLUDE_LIST"
assert_eq "one warning for blank" "1" "$SKIP_WARNINGS"
assert_contains "warning mentions 'blank'" "blank" "$stderr"
printf "\n"

# --------------------------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------------------------
printf "\n=== Results: %d passed, %d failed (of %d tests) ===\n" "$PASS" "$FAIL" "$TESTS_RUN"

if [ "$FAIL" -gt 0 ]; then
  printf "\nFailed tests:%s\n\n" "$FAILURES"
  exit 1
fi

printf "\nAll tests passed.\n\n"
exit 0
