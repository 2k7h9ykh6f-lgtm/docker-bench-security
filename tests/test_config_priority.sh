#!/bin/bash
# --------------------------------------------------------------------------------------------
# test_config_priority.sh - Tests for the unified configuration loading system
#
# Verifies:
#   1. Default values take effect when no overrides exist
#   2. Config file values override defaults
#   3. Environment variables override config file
#   4. CLI arguments override everything
#   5. Unknown config file keys produce an error
#   6. Source tracking correctly labels each value's origin
# --------------------------------------------------------------------------------------------

set -e

# --- Helpers -----------------------------------------------------------------
PASS=0
FAIL=0
TOTAL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    printf "  PASS: %s\n" "$desc"
    PASS=$((PASS + 1))
  else
    printf "  FAIL: %s\n        expected: '%s'\n        actual:   '%s'\n" "$desc" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_code() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    printf "  PASS: %s (exit code %s)\n" "$desc" "$actual"
    PASS=$((PASS + 1))
  else
    printf "  FAIL: %s\n        expected exit code: %s\n        actual exit code:   %s\n" "$desc" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

# Reset all config variables and source tracking before each test
reset_config() {
  nocolor=""
  logger=""
  limit=""
  printremediation=""
  dockertrustusers=""
  check=""
  checkexclude=""
  include=""
  exclude=""
  labels=""
  # Clear source tracking
  for _k in $DBS_KNOWN_KEYS; do
    eval "unset __cfg_src_${_k}"
  done
  # Clear CLI markers
  unset _cli_nocolor _cli_logger _cli_limit _cli_printremediation
  unset _cli_dockertrustusers _cli_check _cli_checkexclude
  unset _cli_include _cli_exclude _cli_labels
  # Clear env vars
  unset DBS_NO_COLOR DBS_LOG_FILE DBS_LIMIT DBS_PRINT_REMEDIATION
  unset DBS_TRUSTED_USERS DBS_CHECK DBS_CHECK_EXCLUDE
  unset DBS_INCLUDE DBS_EXCLUDE DBS_LABELS DBS_CONFIG_FILE
}

# Setup: need myname for default logger path
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
myname="docker-bench-security"

# Source the config library
. "$SCRIPT_DIR/functions/config_lib.sh"

# Create a temp directory for test config files
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

printf "=== Test Suite: Configuration Priority ===\n\n"

# --- Test 1: Defaults take effect --------------------------------------------
printf "[Test 1] Default values take effect when no overrides exist\n"
reset_config

_cfg_apply_defaults

assert_eq "nocolor defaults to empty"       ""              "$nocolor"
assert_eq "logger defaults to log/docker-bench-security.log" "log/docker-bench-security.log" "$logger"
assert_eq "limit defaults to 0"             "0"             "$limit"
assert_eq "printremediation defaults to 0"  "0"             "$printremediation"
assert_eq "dockertrustusers defaults to empty" ""            "$dockertrustusers"
assert_eq "check defaults to empty"         ""              "$check"
assert_eq "checkexclude defaults to empty"  ""              "$checkexclude"
assert_eq "include defaults to empty"       ""              "$include"
assert_eq "exclude defaults to empty"       ""              "$exclude"
assert_eq "labels defaults to empty"        ""              "$labels"

# Verify source tracking says "default"
assert_eq "source of limit is 'default'"    "default"       "$(cfg_get_source limit)"
assert_eq "source of logger is 'default'"   "default"       "$(cfg_get_source logger)"
printf "\n"

# --- Test 2: Config file overrides defaults ----------------------------------
printf "[Test 2] Config file values override defaults\n"
reset_config

cat > "$TMPDIR/test.conf" <<'CONF'
# Test configuration
LIMIT=10
PRINT_REMEDIATION=1
TRUSTED_USERS=admin,deploy
LOG_FILE=/var/log/dbs.log
CONF

_cfg_apply_defaults
_cfg_load_file "$TMPDIR/test.conf"

assert_eq "limit overridden by file"            "10"                    "$limit"
assert_eq "printremediation overridden by file" "1"                     "$printremediation"
assert_eq "dockertrustusers set by file"        "admin,deploy"          "$dockertrustusers"
assert_eq "logger overridden by file"           "/var/log/dbs.log"      "$logger"
assert_eq "nocolor still default (not in file)" ""                      "$nocolor"

assert_eq "source of limit is file"            "file:${TMPDIR}/test.conf" "$(cfg_get_source limit)"
assert_eq "source of nocolor is still default"  "default"                 "$(cfg_get_source nocolor)"
printf "\n"

# --- Test 3: Environment variables override config file ----------------------
printf "[Test 3] Environment variables override config file values\n"
reset_config

cat > "$TMPDIR/test.conf" <<'CONF'
LIMIT=10
LOG_FILE=/var/log/from-file.log
CONF

export DBS_LIMIT=20
export DBS_LOG_FILE="/var/log/from-env.log"

_cfg_apply_defaults
_cfg_load_file "$TMPDIR/test.conf"
_cfg_load_env

assert_eq "limit overridden by env"         "20"                        "$limit"
assert_eq "logger overridden by env"        "/var/log/from-env.log"     "$logger"
assert_eq "source of limit is env"          "env:DBS_LIMIT"             "$(cfg_get_source limit)"
assert_eq "source of logger is env"         "env:DBS_LOG_FILE"          "$(cfg_get_source logger)"

# printremediation was not in file or env, should still be default
assert_eq "printremediation still default"  "0"                         "$printremediation"
assert_eq "source of printremediation"      "default"                   "$(cfg_get_source printremediation)"

unset DBS_LIMIT DBS_LOG_FILE
printf "\n"

# --- Test 4: CLI overrides everything ----------------------------------------
printf "[Test 4] CLI arguments override config file and env vars\n"
reset_config

cat > "$TMPDIR/test.conf" <<'CONF'
LIMIT=10
LOG_FILE=/var/log/from-file.log
PRINT_REMEDIATION=1
CONF

export DBS_LIMIT=20
export DBS_LOG_FILE="/var/log/from-env.log"

_cfg_apply_defaults
_cfg_load_file "$TMPDIR/test.conf"
_cfg_load_env

# Simulate CLI: -n 5 -l /tmp/cli.log
# (In the real script, getopts sets these directly)
limit=5
_cli_limit=1
logger="/tmp/cli.log"
_cli_logger=1

_cfg_mark_cli

assert_eq "limit from CLI wins over file and env" "5"                   "$limit"
assert_eq "logger from CLI wins over file and env" "/tmp/cli.log"       "$logger"
assert_eq "printremediation from file (no CLI override)" "1"            "$printremediation"

assert_eq "source of limit is cli"          "cli:-n"                    "$(cfg_get_source limit)"
assert_eq "source of logger is cli"         "cli:-l"                    "$(cfg_get_source logger)"
assert_eq "source of printremediation is file" "file:${TMPDIR}/test.conf" "$(cfg_get_source printremediation)"

unset DBS_LIMIT DBS_LOG_FILE
printf "\n"

# --- Test 5: Unknown config keys produce error --------------------------------
printf "[Test 5] Unknown configuration keys produce an error\n"
reset_config

cat > "$TMPDIR/bad.conf" <<'CONF'
LIMIT=10
BOGUS_KEY=should_fail
ANOTHER_BAD=nope
CONF

_cfg_apply_defaults
set +e
_cfg_load_file "$TMPDIR/bad.conf" 2>"$TMPDIR/stderr.txt"
exit_code=$?
set -e

assert_exit_code "unknown keys cause non-zero exit" "1" "$exit_code"

# Check that the error message mentions the unknown keys
stderr_content="$(cat "$TMPDIR/stderr.txt")"
TOTAL=$((TOTAL + 1))
if printf '%s' "$stderr_content" | grep -q "BOGUS_KEY"; then
  printf "  PASS: error message mentions BOGUS_KEY\n"
  PASS=$((PASS + 1))
else
  printf "  FAIL: error message should mention BOGUS_KEY\n        got: %s\n" "$stderr_content"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
if printf '%s' "$stderr_content" | grep -q "ANOTHER_BAD"; then
  printf "  PASS: error message mentions ANOTHER_BAD\n"
  PASS=$((PASS + 1))
else
  printf "  FAIL: error message should mention ANOTHER_BAD\n        got: %s\n" "$stderr_content"
  FAIL=$((FAIL + 1))
fi
printf "\n"

# --- Test 6: Full integration - load_config -----------------------------------
printf "[Test 6] Full integration: load_config applies all layers in order\n"
reset_config

cat > "$TMPDIR/integration.conf" <<'CONF'
LIMIT=50
LOG_FILE=/var/log/integration.log
NO_COLOR=nocolor
CHECK=check_2_1,check_2_2
CONF

export DBS_LIMIT=99
export DBS_CHECK="check_3_1"

# Simulate CLI override: -n 7 -c check_4_1
# We need to manually set CLI values as getopts would, then call _cfg_mark_cli
# First, set config file path and call load_config parts manually

_cfg_apply_defaults
_cfg_load_file "$TMPDIR/integration.conf"
_cfg_load_env

# Now simulate CLI overrides: only -n 7 (not -c)
limit=7
_cli_limit=1
_cfg_mark_cli

assert_eq "CLI limit=7 wins over env=99 and file=50" "7"               "$limit"
assert_eq "env check=check_3_1 wins over file (no CLI for check)" "check_3_1" "$check"
assert_eq "file nocolor=nocolor (no env or CLI override)" "nocolor"    "$nocolor"
assert_eq "file logger (no env or CLI override)" "/var/log/integration.log" "$logger"

assert_eq "source of limit"   "cli:-n"              "$(cfg_get_source limit)"
assert_eq "source of check"   "env:DBS_CHECK"       "$(cfg_get_source check)"
assert_eq "source of nocolor" "file:${TMPDIR}/integration.conf" "$(cfg_get_source nocolor)"
assert_eq "source of logger"  "file:${TMPDIR}/integration.conf" "$(cfg_get_source logger)"

unset DBS_LIMIT DBS_CHECK
printf "\n"

# --- Test 7: Config file with quoted values ----------------------------------
printf "[Test 7] Config file handles quoted values correctly\n"
reset_config

cat > "$TMPDIR/quoted.conf" <<'CONF'
LOG_FILE="/var/log/quoted path.log"
TRUSTED_USERS='user1,user2'
CONF

_cfg_apply_defaults
_cfg_load_file "$TMPDIR/quoted.conf"

assert_eq "double-quoted value stripped"  "/var/log/quoted path.log" "$logger"
assert_eq "single-quoted value stripped"  "user1,user2"              "$dockertrustusers"
printf "\n"

# --- Test 8: Missing config file is not an error -----------------------------
printf "[Test 8] Missing config file is silently skipped\n"
reset_config

_cfg_apply_defaults
set +e
_cfg_load_file "$TMPDIR/nonexistent.conf"
exit_code=$?
set -e

assert_exit_code "missing file returns 0 (no error)" "0" "$exit_code"
assert_eq "defaults still in place" "0" "$limit"
printf "\n"

# --- Test 9: Invalid line (no =) in config file ------------------------------
printf "[Test 9] Invalid config file line produces error\n"
reset_config

cat > "$TMPDIR/invalid.conf" <<'CONF'
LIMIT=10
this line has no equals sign
CONF

_cfg_apply_defaults
set +e
_cfg_load_file "$TMPDIR/invalid.conf" 2>"$TMPDIR/stderr_invalid.txt"
exit_code=$?
set -e

assert_exit_code "invalid line causes error" "1" "$exit_code"
TOTAL=$((TOTAL + 1))
if grep -q "invalid line" "$TMPDIR/stderr_invalid.txt"; then
  printf "  PASS: error message mentions invalid line\n"
  PASS=$((PASS + 1))
else
  printf "  FAIL: error message should mention invalid line\n"
  FAIL=$((FAIL + 1))
fi
printf "\n"

# --- Test 10: Source summary output ------------------------------------------
printf "[Test 10] cfg_print_summary produces readable output\n"
reset_config

# Need color vars for summary output
bldylw=''
txtrst=''

_cfg_apply_defaults
limit=42
_cli_limit=1
_cfg_mark_cli

summary_output="$(cfg_print_summary 2>&1)"
TOTAL=$((TOTAL + 1))
if printf '%s' "$summary_output" | grep -q "Configuration summary"; then
  printf "  PASS: summary contains header\n"
  PASS=$((PASS + 1))
else
  printf "  FAIL: summary missing header\n"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
if printf '%s' "$summary_output" | grep -q "cli:-n"; then
  printf "  PASS: summary shows CLI source for limit\n"
  PASS=$((PASS + 1))
else
  printf "  FAIL: summary should show CLI source for limit\n        got: %s\n" "$summary_output"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
if printf '%s' "$summary_output" | grep -q "42"; then
  printf "  PASS: summary shows resolved value 42\n"
  PASS=$((PASS + 1))
else
  printf "  FAIL: summary should show value 42\n"
  FAIL=$((FAIL + 1))
fi
printf "\n"

# --- Results -----------------------------------------------------------------
printf "========================================\n"
printf "Results: %d passed, %d failed, %d total\n" "$PASS" "$FAIL" "$TOTAL"
printf "========================================\n"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
