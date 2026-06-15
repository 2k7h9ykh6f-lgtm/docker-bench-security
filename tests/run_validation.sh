#!/bin/bash
# ============================================================
# Validation tests for the check registry and dispatch logic.
# Does NOT require Docker. Tests registry structure only.
#
# Usage:  bash tests/run_validation.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

# --- Assertion helpers ---

assert_equals() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  PASS: %s\n" "$label"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  FAIL: %s\n    expected: %s\n    actual:   %s\n" "$label" "$expected" "$actual"
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  PASS: %s\n" "$label"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  FAIL: %s (not found: '%s')\n" "$label" "$needle"
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if ! printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  PASS: %s\n" "$label"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  FAIL: %s (unexpectedly found: '%s')\n" "$label" "$needle"
  fi
}

assert_exit_nonzero() {
  local label="$1"
  shift
  if "$@" 2>/dev/null; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  FAIL: %s (expected failure, got success)\n" "$label"
  else
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  PASS: %s\n" "$label"
  fi
}

assert_exit_zero() {
  local label="$1"
  shift
  if "$@" 2>/dev/null; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  PASS: %s\n" "$label"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  FAIL: %s (expected success, got failure)\n" "$label"
  fi
}

# --- Setup: source registry and define stubs ---

LIBEXEC="$SCRIPT_DIR"
. "$SCRIPT_DIR/functions/registry_lib.sh"

# Collect all unique leaf function names from every group,
# then define a stub for each that records its invocation.
_CALL_LOG=""

_all_leaf_funcs=""
for _grp in $_ALL_GROUPS; do
  _leaves=$(expand_group "$_grp" 2>/dev/null) || true
  _all_leaf_funcs="$_all_leaf_funcs $_leaves"
done
# De-duplicate
_all_leaf_funcs=$(printf '%s\n' $_all_leaf_funcs | sort -u)

for _fn in $_all_leaf_funcs; do
  eval "${_fn}() { _CALL_LOG=\"\${_CALL_LOG} ${_fn}\"; }"
done

# ============================================================
# Test 1: Listing all checks
# ============================================================
printf "Test 1: Listing all checks\n"

all_checks=$(expand_group all)
# Count unique leaf functions in the "all" group
count=$(printf '%s\n' $all_checks | sort -u | wc -l | tr -d ' ')

assert_equals "all group expands to non-empty list" "true" \
  "$([ -n "$all_checks" ] && echo true || echo false)"
assert_equals "total unique check count from all group" "156" "$count"

# Spot-check specific functions across different sections
assert_contains "check_1_1_1 in all" "$all_checks" "check_1_1_1"
assert_contains "check_2_18 in all" "$all_checks" "check_2_18"
assert_contains "check_3_24 in all" "$all_checks" "check_3_24"
assert_contains "check_4_12 in all" "$all_checks" "check_4_12"
assert_contains "check_5_32 in all" "$all_checks" "check_5_32"
assert_contains "check_6_2 in all" "$all_checks" "check_6_2"
assert_contains "check_7_9 in all" "$all_checks" "check_7_9"
assert_contains "check_8_2_1 in all" "$all_checks" "check_8_2_1"
assert_contains "check_c_5_3_4 in all" "$all_checks" "check_c_5_3_4"
assert_contains "check_running_containers in all" "$all_checks" "check_running_containers"
assert_contains "check_product_license in all" "$all_checks" "check_product_license"

# Verify section headers and ends are present
assert_contains "check_1 (section header) in all" "$all_checks" "check_1"
assert_contains "check_1_end in all" "$all_checks" "check_1_end"

# Verify cis group does NOT include enterprise or community
cis_checks=$(expand_group cis)
assert_not_contains "no enterprise checks in cis" "$cis_checks" "check_8_1_1"
assert_not_contains "no community checks in cis" "$cis_checks" "check_c_1"

# ============================================================
# Test 2: Executing a single group
# ============================================================
printf "\nTest 2: Executing a single group\n"

_CALL_LOG=""
run_group docker_security_operations
expected=" check_6 check_6_1 check_6_2 check_6_end"
assert_equals "docker_security_operations runs correct checks in order" \
  "$expected" "$_CALL_LOG"

# Test backward-compatible wrapper function
_CALL_LOG=""
docker_security_operations
assert_equals "wrapper function works identically" "$expected" "$_CALL_LOG"

# Test a composite group (cis runs 7 sub-groups in order)
_CALL_LOG=""
run_group docker_swarm_configuration
sw_expected=" check_7 check_7_1 check_7_2 check_7_3 check_7_4 check_7_5 check_7_6 check_7_7 check_7_8 check_7_9 check_7_end"
assert_equals "docker_swarm_configuration runs all section 7 checks" \
  "$sw_expected" "$_CALL_LOG"

# Test community group
_CALL_LOG=""
run_group community_checks
cm_expected=" check_c check_c_1 check_c_1_1 check_c_2 check_c_5_3_1 check_c_5_3_2 check_c_5_3_3 check_c_5_3_4 check_c_end"
assert_equals "community_checks runs all community checks" \
  "$cm_expected" "$_CALL_LOG"

# ============================================================
# Test 3: Exclude filtering
# ============================================================
printf "\nTest 3: Exclude filtering\n"

# Simulate: run docker_security_operations excluding check_6_2
exclude_list="check_6_2"
checkexcluded="$(echo ",$exclude_list" | sed -e 's/^/\^/g' -e 's/,/\$|/g' -e 's/$/\$/g')"

_CALL_LOG=""
for lc in $(expand_group docker_security_operations); do
  if echo "$lc" | grep -vE "$checkexcluded" 2>/dev/null 1>&2; then
    "$lc"
  fi
done
assert_contains "check_6 was called" "$_CALL_LOG" "check_6"
assert_contains "check_6_1 was called" "$_CALL_LOG" "check_6_1"
assert_not_contains "check_6_2 was excluded" "$_CALL_LOG" "check_6_2"
assert_contains "check_6_end was called" "$_CALL_LOG" "check_6_end"

# Multi-exclude
exclude_list="check_6_1,check_6_2"
checkexcluded="$(echo ",$exclude_list" | sed -e 's/^/\^/g' -e 's/,/\$|/g' -e 's/$/\$/g')"

_CALL_LOG=""
for lc in $(expand_group docker_security_operations); do
  if echo "$lc" | grep -vE "$checkexcluded" 2>/dev/null 1>&2; then
    "$lc"
  fi
done
assert_not_contains "check_6_1 excluded in multi-exclude" "$_CALL_LOG" "check_6_1"
assert_not_contains "check_6_2 excluded in multi-exclude" "$_CALL_LOG" "check_6_2"
assert_contains "check_6 still called in multi-exclude" "$_CALL_LOG" "check_6"
assert_contains "check_6_end still called in multi-exclude" "$_CALL_LOG" "check_6_end"

# Exclude an entire group name passed via -c
# Simulate: -c "host_configuration,docker_security_operations" -e "docker_security_operations"
exclude_list="docker_security_operations"
checkexcluded="$(echo ",$exclude_list" | sed -e 's/^/\^/g' -e 's/,/\$|/g' -e 's/$/\$/g')"

skip_group="false"
if echo "docker_security_operations" | grep -E "$checkexcluded" 2>/dev/null 1>&2; then
  skip_group="true"
fi
assert_equals "group-level exclude matches" "true" "$skip_group"

# ============================================================
# Test 4: Unknown check/group handling
# ============================================================
printf "\nTest 4: Unknown check/group handling\n"

result=$(get_group_members "nonexistent_group")
assert_equals "unknown group returns empty" "" "$result"
assert_exit_nonzero "run_group fails for unknown group" run_group "nonexistent_group"
assert_equals "is_group false for unknown" "false" \
  "$(is_group nonexistent_group && echo true || echo false)"
assert_equals "is_group true for known group" "true" \
  "$(is_group cis && echo true || echo false)"
assert_equals "is_group true for leaf group" "true" \
  "$(is_group docker_security_operations && echo true || echo false)"

# Validate name rejects injection attempts
assert_exit_nonzero "validate rejects semicolon" _validate_name "foo;bar"
assert_exit_nonzero "validate rejects space" _validate_name "foo bar"
assert_exit_nonzero "validate rejects empty" _validate_name ""
assert_exit_zero "validate accepts clean name" _validate_name "check_1_1"

# ============================================================
# Test 5: Registry consistency
# ============================================================
printf "\nTest 5: Registry consistency\n"

# Every leaf function referenced in every group should have a stub defined
missing=0
for _grp in $_ALL_GROUPS; do
  for func in $(expand_group "$_grp" 2>/dev/null); do
    if ! command -v "$func" >/dev/null 2>&1; then
      printf "  MISSING: %s (referenced in group %s)\n" "$func" "$_grp"
      missing=$((missing + 1))
    fi
  done
done
assert_equals "no missing function references" "0" "$missing"

# Every group in _ALL_GROUPS should have a non-empty _REG_ variable
empty_groups=0
for _grp in $_ALL_GROUPS; do
  if ! is_group "$_grp"; then
    printf "  EMPTY: group %s has no _REG_ definition\n" "$_grp"
    empty_groups=$((empty_groups + 1))
  fi
done
assert_equals "all listed groups have definitions" "0" "$empty_groups"

# Section groups should start with their header and end with _end
for section in host_configuration docker_daemon_configuration docker_daemon_files \
               container_images container_runtime docker_security_operations \
               docker_swarm_configuration docker_enterprise_configuration community_checks; do
  members=$(get_group_members "$section")
  first=$(echo "$members" | awk '{print $1}')
  last=$(echo "$members" | awk '{print $NF}')
  assert_contains "$section starts with section header" "$first" "check_"
  assert_contains "$section ends with _end" "$last" "_end"
done

# ============================================================
# Summary
# ============================================================
printf "\n========================================\n"
printf "Results: %d passed, %d failed\n" "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
