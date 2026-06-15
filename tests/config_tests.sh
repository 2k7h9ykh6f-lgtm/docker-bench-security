#!/bin/bash
# --------------------------------------------------------------------------------------------
# Tests for config_lib.sh - Docker Bench for Security configuration loading
#
# Run: bash tests/config_tests.sh
# --------------------------------------------------------------------------------------------

set -u

# Resolve script location to find config_lib.sh
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# --- Mini test framework ---

_test_count=0
_test_pass=0
_test_fail=0
_test_current_group=""

test_group() {
  _test_current_group="$1"
  printf "\n== %s ==\n" "$1"
}

assert_eq() {
  _test_count=$((_test_count + 1))
  if [ "$2" = "$3" ]; then
    _test_pass=$((_test_pass + 1))
    printf "  PASS: %s\n" "$1"
  else
    _test_fail=$((_test_fail + 1))
    printf "  FAIL: %s\n    expected: '%s'\n    got:      '%s'\n" "$1" "$2" "$3"
  fi
}

assert_neq() {
  _test_count=$((_test_count + 1))
  if [ "$2" != "$3" ]; then
    _test_pass=$((_test_pass + 1))
    printf "  PASS: %s\n" "$1"
  else
    _test_fail=$((_test_fail + 1))
    printf "  FAIL: %s (expected values to differ, both are '%s')\n" "$1" "$2"
  fi
}

assert_match() {
  _test_count=$((_test_count + 1))
  if printf '%s' "$3" | grep -qE "$2"; then
    _test_pass=$((_test_pass + 1))
    printf "  PASS: %s\n" "$1"
  else
    _test_fail=$((_test_fail + 1))
    printf "  FAIL: %s\n    pattern:  '%s'\n    got:      '%s'\n" "$1" "$2" "$3"
  fi
}

test_summary() {
  printf "\n==============================\n"
  printf "Results: %d/%d passed, %d failed\n" "$_test_pass" "$_test_count" "$_test_fail"
  printf "==============================\n"
  if [ "$_test_fail" -eq 0 ]; then
    return 0
  fi
  return 1
}

# --- Test helpers ---

_tmpdir=""

# Provide a mock logit since output_lib.sh is not sourced
logit() {
  printf "%b\n" "$1" > /dev/null
}

setup_test_env() {
  _tmpdir=$(mktemp -d)

  # Unset all DBS_* env vars
  unset DBS_LOG_FILE DBS_NO_COLOR DBS_LIMIT DBS_PRINT_REMEDIATION \
        DBS_TRUST_USERS DBS_CHECK DBS_CHECK_EXCLUDE DBS_INCLUDE \
        DBS_EXCLUDE DBS_LABELS DBS_CONFIG_FILE 2>/dev/null

  # Clear all config variables and sources
  logger="" ; logger_src=""
  nocolor="" ; nocolor_src=""
  limit="" ; limit_src=""
  printremediation="" ; printremediation_src=""
  dockertrustusers="" ; dockertrustusers_src=""
  check="" ; check_src=""
  checkexclude="" ; checkexclude_src=""
  include="" ; include_src=""
  exclude="" ; exclude_src=""
  labels="" ; labels_src=""

  # Set myname as the main script would
  myname="docker-bench-security"

  # Source config_lib.sh fresh
  . "$SCRIPT_DIR/functions/config_lib.sh"
}

cleanup_test_env() {
  if [ -n "$_tmpdir" ] && [ -d "$_tmpdir" ]; then
    rm -rf "$_tmpdir"
  fi
  unset DBS_LOG_FILE DBS_NO_COLOR DBS_LIMIT DBS_PRINT_REMEDIATION \
        DBS_TRUST_USERS DBS_CHECK DBS_CHECK_EXCLUDE DBS_INCLUDE \
        DBS_EXCLUDE DBS_LABELS DBS_CONFIG_FILE 2>/dev/null
}

write_config() {
  printf '%s\n' "$2" > "$1"
}

# --- Test Groups ---

# Group 1: Defaults
test_defaults_applied() {
  test_group "1. Defaults applied"
  setup_test_env
  config_set_defaults

  assert_eq "default logger" "log/docker-bench-security.log" "$logger"
  assert_eq "default logger_src" "default" "$logger_src"
  assert_eq "default limit" "0" "$limit"
  assert_eq "default limit_src" "default" "$limit_src"
  assert_eq "default nocolor" "" "$nocolor"
  assert_eq "default nocolor_src" "default" "$nocolor_src"
  assert_eq "default printremediation" "0" "$printremediation"
  assert_eq "default printremediation_src" "default" "$printremediation_src"
  assert_eq "default dockertrustusers" "" "$dockertrustusers"
  assert_eq "default dockertrustusers_src" "default" "$dockertrustusers_src"
  assert_eq "default check" "" "$check"
  assert_eq "default check_src" "default" "$check_src"
  assert_eq "default checkexclude" "" "$checkexclude"
  assert_eq "default include" "" "$include"
  assert_eq "default exclude" "" "$exclude"
  assert_eq "default labels" "" "$labels"

  cleanup_test_env
}

# Group 2: Config file overrides defaults
test_config_file_overrides_defaults() {
  test_group "2. Config file overrides defaults"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/test.conf" "log_file=/var/log/dbs.log
limit=10
no_color=true
print_remediation=yes
trust_users=alice,bob"

  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file

  assert_eq "config logger" "/var/log/dbs.log" "$logger"
  assert_eq "config logger_src" "config:$_tmpdir/test.conf" "$logger_src"
  assert_eq "config limit" "10" "$limit"
  assert_eq "config limit_src" "config:$_tmpdir/test.conf" "$limit_src"
  assert_eq "config nocolor" "nocolor" "$nocolor"
  assert_eq "config nocolor_src" "config:$_tmpdir/test.conf" "$nocolor_src"
  assert_eq "config printremediation" "1" "$printremediation"
  assert_eq "config printremediation_src" "config:$_tmpdir/test.conf" "$printremediation_src"
  assert_eq "config dockertrustusers" "alice,bob" "$dockertrustusers"
  # Keys not in config file retain default source
  assert_eq "check still default" "default" "$check_src"
  assert_eq "exclude still default" "default" "$exclude_src"

  cleanup_test_env
}

# Group 3: Environment variables override config file
test_env_overrides_config() {
  test_group "3. Env overrides config file"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/test.conf" "limit=10
log_file=/var/log/from-config.log"

  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file

  assert_eq "limit from config" "10" "$limit"
  assert_eq "logger from config" "/var/log/from-config.log" "$logger"

  export DBS_LIMIT=25
  export DBS_LOG_FILE="/var/log/from-env.log"
  config_load_env

  assert_eq "limit from env" "25" "$limit"
  assert_eq "limit_src from env" "env:DBS_LIMIT" "$limit_src"
  assert_eq "logger from env" "/var/log/from-env.log" "$logger"
  assert_eq "logger_src from env" "env:DBS_LOG_FILE" "$logger_src"

  cleanup_test_env
}

# Group 4: CLI overrides everything
test_cli_overrides_all() {
  test_group "4. CLI overrides everything"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/test.conf" "limit=10"
  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file

  export DBS_LIMIT=25
  config_load_env

  assert_eq "limit before cli" "25" "$limit"

  config_set_from_cli limit "50" "-n"

  assert_eq "limit from cli" "50" "$limit"
  assert_eq "limit_src from cli" "cli:-n" "$limit_src"

  cleanup_test_env
}

# Group 5: Full priority chain in one test
test_full_priority_chain() {
  test_group "5. Full priority chain (default -> config -> env -> cli)"
  setup_test_env
  config_set_defaults

  # Step 1: defaults
  assert_eq "step1: limit default" "0" "$limit"
  assert_eq "step1: limit_src" "default" "$limit_src"

  # Step 2: config overrides default
  write_config "$_tmpdir/test.conf" "limit=10"
  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file
  assert_eq "step2: limit config" "10" "$limit"
  assert_eq "step2: limit_src" "config:$_tmpdir/test.conf" "$limit_src"

  # Step 3: env overrides config
  export DBS_LIMIT=25
  config_load_env
  assert_eq "step3: limit env" "25" "$limit"
  assert_eq "step3: limit_src" "env:DBS_LIMIT" "$limit_src"

  # Step 4: cli overrides env
  config_set_from_cli limit "50" "-n"
  assert_eq "step4: limit cli" "50" "$limit"
  assert_eq "step4: limit_src" "cli:-n" "$limit_src"

  cleanup_test_env
}

# Group 6: Unknown config key rejected
test_unknown_key_rejected() {
  test_group "6. Unknown config key rejected"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/bad.conf" "limit=5
unknown_key=bad_value"

  _stderr=$(DBS_CONFIG_FILE="$_tmpdir/bad.conf" config_load_file 2>&1)
  _rc=$?

  assert_eq "unknown key returns error" "1" "$_rc"
  assert_match "error mentions unknown key" "unknown_key" "$_stderr"

  cleanup_test_env
}

# Group 7: Validation - bad limit
test_validate_bad_limit() {
  test_group "7. Validation: bad limit"
  setup_test_env
  config_set_defaults
  config_set_from_cli limit "abc" "-n"

  _stderr=$(config_validate 2>&1)
  _rc=$?

  assert_eq "validate rejects bad limit" "1" "$_rc"
  assert_match "error mentions limit" "limit" "$_stderr"
  assert_match "error mentions source" "cli:-n" "$_stderr"

  cleanup_test_env
}

# Group 8: Validation - bad log path
test_validate_bad_log_path() {
  test_group "8. Validation: bad log path"
  setup_test_env
  config_set_defaults
  config_set_from_cli logger "/nonexistent_dir_xyz/file.log" "-l"

  _stderr=$(config_validate 2>&1)
  _rc=$?

  assert_eq "validate rejects bad log path" "1" "$_rc"
  assert_match "error mentions directory" "directory" "$_stderr"
  assert_match "error mentions source" "cli:-l" "$_stderr"

  cleanup_test_env
}

# Group 9: Validation - good config passes
test_validate_good_config() {
  test_group "9. Validation: good config passes"
  setup_test_env
  config_set_defaults

  # Default log dir 'log/' won't exist in tmpdir; point to tmpdir instead
  config_set_from_cli logger "$_tmpdir/test.log" "-l"

  config_validate
  _rc=$?

  assert_eq "defaults pass validation" "0" "$_rc"

  cleanup_test_env
}

# Group 10: Comments and blank lines ignored
test_comments_and_blanks() {
  test_group "10. Comments and blank lines ignored"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/test.conf" "# This is a comment
   # Indented comment

limit=42

  # Another comment
"

  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file
  _rc=$?

  assert_eq "parse succeeds" "0" "$_rc"
  assert_eq "limit parsed" "42" "$limit"
  # Other values should still be defaults
  assert_eq "logger still default" "default" "$logger_src"

  cleanup_test_env
}

# Group 11: Quoted values
test_quoted_values() {
  test_group "11. Quoted values"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/test.conf" 'log_file="/tmp/my log.log"
trust_users='"'"'alice,bob'"'"''

  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file

  assert_eq "double-quoted value" "/tmp/my log.log" "$logger"
  assert_eq "single-quoted value" "alice,bob" "$dockertrustusers"

  cleanup_test_env
}

# Group 12: Boolean normalization
test_bool_normalization() {
  test_group "12. Boolean normalization"
  setup_test_env

  # Test all truthy values for no_color
  for val in true TRUE True yes YES Yes 1; do
    config_set_defaults
    write_config "$_tmpdir/bool.conf" "no_color=$val"
    DBS_CONFIG_FILE="$_tmpdir/bool.conf" config_load_file
    assert_eq "no_color=$val -> nocolor" "nocolor" "$nocolor"
  done

  # Test all falsy values for no_color
  for val in false FALSE False no NO No 0; do
    config_set_defaults
    write_config "$_tmpdir/bool.conf" "no_color=$val"
    DBS_CONFIG_FILE="$_tmpdir/bool.conf" config_load_file
    assert_eq "no_color=$val -> empty" "" "$nocolor"
  done

  # Test print_remediation booleans
  config_set_defaults
  write_config "$_tmpdir/bool.conf" "print_remediation=yes"
  DBS_CONFIG_FILE="$_tmpdir/bool.conf" config_load_file
  assert_eq "print_remediation=yes -> 1" "1" "$printremediation"

  config_set_defaults
  write_config "$_tmpdir/bool.conf" "print_remediation=no"
  DBS_CONFIG_FILE="$_tmpdir/bool.conf" config_load_file
  assert_eq "print_remediation=no -> 0" "0" "$printremediation"

  cleanup_test_env
}

# Group 13: Environment boolean normalization
test_env_bool_normalization() {
  test_group "13. Env boolean normalization"
  setup_test_env
  config_set_defaults

  export DBS_NO_COLOR=yes
  config_load_env
  assert_eq "DBS_NO_COLOR=yes -> nocolor" "nocolor" "$nocolor"
  assert_eq "nocolor_src" "env:DBS_NO_COLOR" "$nocolor_src"

  unset DBS_NO_COLOR
  config_set_defaults
  export DBS_NO_COLOR=0
  config_load_env
  assert_eq "DBS_NO_COLOR=0 -> empty" "" "$nocolor"

  export DBS_PRINT_REMEDIATION=true
  config_load_env
  assert_eq "DBS_PRINT_REMEDIATION=true -> 1" "1" "$printremediation"

  cleanup_test_env
}

# Group 14: config_get_source helper
test_get_source() {
  test_group "14. config_get_source helper"
  setup_test_env
  config_set_defaults

  assert_eq "get_source default" "default" "$(config_get_source logger)"

  config_set_from_cli logger "/tmp/test.log" "-l"
  assert_eq "get_source cli" "cli:-l" "$(config_get_source logger)"

  cleanup_test_env
}

# Group 15: No config file found is not an error
test_no_config_file_ok() {
  test_group "15. No config file found is not an error"
  setup_test_env
  config_set_defaults

  # Point DBS_CONFIG_FILE to nothing, and ensure no local/system config exists
  # by not setting DBS_CONFIG_FILE and running from tmpdir
  (cd "$_tmpdir" && config_load_file)
  _rc=$?

  assert_eq "no config file returns 0" "0" "$_rc"

  cleanup_test_env
}

# Group 16: DBS_CONFIG_FILE pointing to missing file is an error
test_missing_explicit_config_file() {
  test_group "16. Missing explicit config file is an error"
  setup_test_env
  config_set_defaults

  _stderr=$(DBS_CONFIG_FILE="$_tmpdir/nonexistent.conf" config_load_file 2>&1)
  _rc=$?

  assert_eq "missing file returns error" "1" "$_rc"
  assert_match "error mentions file" "nonexistent.conf" "$_stderr"

  cleanup_test_env
}

# Group 17: Source annotation preserved across full chain
test_source_annotation_preserved() {
  test_group "17. Source annotation preserved across layers"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/test.conf" "log_file=/var/log/dbs.log
limit=10"
  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file

  export DBS_NO_COLOR=true
  config_load_env

  config_set_from_cli check "check_2_2" "-c"

  # Each variable should reflect the layer that last set it
  assert_eq "logger_src from config" "config:$_tmpdir/test.conf" "$logger_src"
  assert_eq "limit_src from config" "config:$_tmpdir/test.conf" "$limit_src"
  assert_eq "nocolor_src from env" "env:DBS_NO_COLOR" "$nocolor_src"
  assert_eq "check_src from cli" "cli:-c" "$check_src"
  assert_eq "exclude_src from default" "default" "$exclude_src"

  cleanup_test_env
}

# Group 18: Whitespace around equals
test_whitespace_around_equals() {
  test_group "18. Whitespace around equals sign"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/test.conf" "limit = 10
log_file = /tmp/test.log"

  DBS_CONFIG_FILE="$_tmpdir/test.conf" config_load_file
  _rc=$?

  assert_eq "parse succeeds" "0" "$_rc"
  assert_eq "limit with spaces" "10" "$limit"
  assert_eq "log_file with spaces" "/tmp/test.log" "$logger"

  cleanup_test_env
}

# Group 19: Invalid boolean in config file
test_invalid_bool_in_config() {
  test_group "19. Invalid boolean in config file"
  setup_test_env
  config_set_defaults

  write_config "$_tmpdir/bad.conf" "no_color=maybe"

  _stderr=$(DBS_CONFIG_FILE="$_tmpdir/bad.conf" config_load_file 2>&1)
  _rc=$?

  assert_eq "invalid bool returns error" "1" "$_rc"
  assert_match "error mentions value" "maybe" "$_stderr"

  cleanup_test_env
}

# Group 20: Multiple validation errors reported
test_multiple_validation_errors() {
  test_group "20. Multiple validation errors reported"
  setup_test_env
  config_set_defaults

  config_set_from_cli limit "not-a-number" "-n"
  config_set_from_cli logger "/no/such/dir/file.log" "-l"

  _stderr=$(config_validate 2>&1)
  _rc=$?

  assert_eq "validate returns error" "1" "$_rc"
  assert_match "reports limit error" "limit" "$_stderr"
  assert_match "reports dir error" "directory" "$_stderr"

  cleanup_test_env
}

# --- Main ---

printf "Running config_lib.sh tests...\n"
printf "Script dir: %s\n" "$SCRIPT_DIR"

test_defaults_applied
test_config_file_overrides_defaults
test_env_overrides_config
test_cli_overrides_all
test_full_priority_chain
test_unknown_key_rejected
test_validate_bad_limit
test_validate_bad_log_path
test_validate_good_config
test_comments_and_blanks
test_quoted_values
test_bool_normalization
test_env_bool_normalization
test_get_source
test_no_config_file_ok
test_missing_explicit_config_file
test_source_annotation_preserved
test_whitespace_around_equals
test_invalid_bool_in_config
test_multiple_validation_errors

test_summary
exit $?
