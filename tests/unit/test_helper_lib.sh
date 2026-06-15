#!/bin/bash
# test_helper_lib.sh — Unit tests for functions/helper_lib.sh
# Covers pure functions that do not require Docker or /proc.

# Source the library under test
# shellcheck disable=SC1091
source "$REPO_ROOT/functions/helper_lib.sh"

# ---------------------------------------------------------------------------
# abspath()
# ---------------------------------------------------------------------------
test_abspath_absolute() {
  local result
  result=$(abspath "/etc/docker/daemon.json")
  assert_eq "/etc/docker/daemon.json" "$result" "absolute path should pass through"
}

test_abspath_relative() {
  local result
  result=$(abspath "relative/path.sh")
  assert_contains "$result" "relative/path.sh" "should contain the relative part"
  # Should start with PWD
  assert_eq "$PWD/relative/path.sh" "$result" "should prepend PWD"
}

test_abspath_dot() {
  local result
  result=$(abspath ".")
  assert_eq "$PWD/." "$result" "dot should expand to PWD/."
}

# ---------------------------------------------------------------------------
# do_version_check()
#   Returns: 10 = equal, 11 = first > second, 9 = first < second
# ---------------------------------------------------------------------------
test_version_equal() {
  do_version_check "1.2.3" "1.2.3"
  assert_eq "10" "$?" "equal versions should return 10"
}

test_version_first_greater() {
  do_version_check "2.0.0" "1.9.9"
  assert_eq "11" "$?" "2.0.0 > 1.9.9 should return 11"
}

test_version_first_lesser() {
  do_version_check "1.0.0" "2.0.0"
  assert_eq "9" "$?" "1.0.0 < 2.0.0 should return 9"
}

test_version_minor_difference() {
  do_version_check "1.20.1" "1.19.3"
  assert_eq "11" "$?" "1.20.1 > 1.19.3 should return 11"
}

test_version_patch_difference() {
  do_version_check "1.2.3" "1.2.4"
  assert_eq "9" "$?" "1.2.3 < 1.2.4 should return 9"
}

test_version_two_segments() {
  do_version_check "20.10" "20.09"
  assert_eq "11" "$?" "20.10 > 20.09 should return 11"
}

test_version_single_segment_equal() {
  do_version_check "5" "5"
  assert_eq "10" "$?" "5 == 5 should return 10"
}

test_version_single_segment_greater() {
  do_version_check "6" "5"
  assert_eq "11" "$?" "6 > 5 should return 11"
}

test_version_single_segment_lesser() {
  do_version_check "4" "5"
  assert_eq "9" "$?" "4 < 5 should return 9"
}

# ---------------------------------------------------------------------------
# auditrules variable
# ---------------------------------------------------------------------------
test_auditrules_default() {
  assert_eq "/etc/audit/audit.rules" "$auditrules" "auditrules should default to /etc/audit/audit.rules"
}
