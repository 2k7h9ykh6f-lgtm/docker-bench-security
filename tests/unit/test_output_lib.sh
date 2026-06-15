#!/bin/bash
# test_output_lib.sh — Unit tests for functions/output_lib.sh
# Covers output formatting, scoring counters, and JSON generation.

# ---------------------------------------------------------------------------
# Setup: prepare the environment output_lib.sh expects
# ---------------------------------------------------------------------------
_TEST_TMPDIR=""
_setup() {
  _TEST_TMPDIR=$(mktemp -d)
  logger="${_TEST_TMPDIR}/test.log"
  nocolor="nocolor"
  totalChecks=0
  currentScore=0
  limit=0
  printremediation="0"
  globalRemediation=""
  # Source the library
  # shellcheck disable=SC1091
  source "$REPO_ROOT/functions/output_lib.sh"
}

_teardown() {
  [ -n "$_TEST_TMPDIR" ] && rm -rf "$_TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Color suppression
# ---------------------------------------------------------------------------
test_nocolor_clears_ansi() {
  _setup
  assert_eq "" "$bldred" "bldred should be empty when nocolor is set"
  assert_eq "" "$bldgrn" "bldgrn should be empty when nocolor is set"
  assert_eq "" "$bldblu" "bldblu should be empty when nocolor is set"
  assert_eq "" "$bldylw" "bldylw should be empty when nocolor is set"
  assert_eq "" "$txtrst" "txtrst should be empty when nocolor is set"
  _teardown
}

# ---------------------------------------------------------------------------
# logit()
# ---------------------------------------------------------------------------
test_logit_writes_stdout_and_file() {
  _setup
  local output
  output=$(logit "hello world")
  assert_contains "$output" "hello world" "logit should print to stdout"
  local logfile_content
  logfile_content=$(cat "$logger")
  assert_contains "$logfile_content" "hello world" "logit should write to log file"
  _teardown
}

# ---------------------------------------------------------------------------
# pass() — scored
# ---------------------------------------------------------------------------
test_pass_scored_increments_counters() {
  _setup
  local output
  output=$(pass -s "check passed")
  assert_eq "1" "$totalChecks" "totalChecks should be 1"
  assert_eq "1" "$currentScore" "currentScore should be 1"
  assert_contains "$output" "PASS" "output should contain PASS"
  assert_contains "$output" "check passed" "output should contain message"
  _teardown
}

# ---------------------------------------------------------------------------
# pass() — unscored (no flags)
# ---------------------------------------------------------------------------
test_pass_unscored_no_counter_change() {
  _setup
  local output
  output=$(pass "just info pass")
  assert_eq "0" "$totalChecks" "totalChecks should remain 0"
  assert_eq "0" "$currentScore" "currentScore should remain 0"
  assert_contains "$output" "PASS" "output should contain PASS"
  _teardown
}

# ---------------------------------------------------------------------------
# pass() — count check only
# ---------------------------------------------------------------------------
test_pass_count_check() {
  _setup
  pass -c "counted pass"
  assert_eq "1" "$totalChecks" "totalChecks should be 1 for -c flag"
  assert_eq "0" "$currentScore" "currentScore should be 0 for -c (no score)"
  _teardown
}

# ---------------------------------------------------------------------------
# warn() — scored
# ---------------------------------------------------------------------------
test_warn_scored_increments_totalchecks_decrements_score() {
  _setup
  local output
  output=$(warn -s "something wrong")
  assert_eq "1" "$totalChecks" "totalChecks should be 1"
  assert_eq "-1" "$currentScore" "currentScore should be -1"
  assert_contains "$output" "WARN" "output should contain WARN"
  assert_contains "$output" "something wrong" "output should contain message"
  _teardown
}

# ---------------------------------------------------------------------------
# warn() — unscored
# ---------------------------------------------------------------------------
test_warn_unscored() {
  _setup
  warn "just a warning"
  assert_eq "0" "$totalChecks" "totalChecks should remain 0"
  assert_eq "0" "$currentScore" "currentScore should remain 0"
  _teardown
}

# ---------------------------------------------------------------------------
# info() — with count check
# ---------------------------------------------------------------------------
test_info_count_check() {
  _setup
  info -c "counted info"
  assert_eq "1" "$totalChecks" "totalChecks should be 1 for info -c"
  _teardown
}

# ---------------------------------------------------------------------------
# info() — without count
# ---------------------------------------------------------------------------
test_info_no_count() {
  _setup
  info "plain info"
  assert_eq "0" "$totalChecks" "totalChecks should remain 0"
  _teardown
}

# ---------------------------------------------------------------------------
# note() — with count check
# ---------------------------------------------------------------------------
test_note_count_check() {
  _setup
  note -c "a note"
  assert_eq "1" "$totalChecks" "totalChecks should be 1 for note -c"
  _teardown
}

# ---------------------------------------------------------------------------
# note() — without count
# ---------------------------------------------------------------------------
test_note_no_count() {
  _setup
  note "plain note"
  assert_eq "0" "$totalChecks" "totalChecks should remain 0"
  _teardown
}

# ---------------------------------------------------------------------------
# yell()
# ---------------------------------------------------------------------------
test_yell_outputs_text() {
  _setup
  local output
  output=$(yell "BANNER TEXT")
  assert_contains "$output" "BANNER TEXT" "yell should output the text"
  _teardown
}

# ---------------------------------------------------------------------------
# Multiple scored calls accumulate correctly
# ---------------------------------------------------------------------------
test_scoring_accumulation() {
  _setup
  pass -s "pass1" > /dev/null
  pass -s "pass2" > /dev/null
  warn -s "fail1" > /dev/null
  pass -s "pass3" > /dev/null
  warn -s "fail2" > /dev/null
  assert_eq "5" "$totalChecks" "totalChecks should be 5 after 5 scored calls"
  # 3 passes (+3) and 2 warns (-2) = +1
  assert_eq "1" "$currentScore" "currentScore should be 1 (3 pass - 2 warn)"
  _teardown
}

# ---------------------------------------------------------------------------
# JSON helpers
# ---------------------------------------------------------------------------
test_beginjson_creates_file() {
  _setup
  beginjson "1.6.0" "1700000000"
  local content
  content=$(cat "${logger}.json")
  assert_contains "$content" "dockerbenchsecurity" "JSON should contain header key"
  assert_contains "$content" "1.6.0" "JSON should contain version"
  assert_contains "$content" "1700000000" "JSON should contain start timestamp"
  _teardown
}

test_endjson_appends_summary() {
  _setup
  beginjson "1.6.0" "1700000000"
  endjson "10" "5" "1700000100"
  local content
  content=$(cat "${logger}.json")
  assert_contains "$content" '"checks": 10' "JSON should contain checks count"
  assert_contains "$content" '"score": 5' "JSON should contain score"
  assert_contains "$content" "1700000100" "JSON should contain end timestamp"
  _teardown
}

test_logjson_adds_key_value() {
  _setup
  beginjson "1.6.0" "1700000000"
  logjson "testkey" "testvalue"
  local content
  content=$(cat "${logger}.json")
  assert_contains "$content" '"testkey": "testvalue"' "JSON should contain key-value pair"
  _teardown
}

test_section_json_structure() {
  _setup
  beginjson "1.6.0" "1700000000"
  startsectionjson "1" "Host Configuration"
  starttestjson "1.1" "Ensure separate partition"
  logcheckresult "PASS"
  endsectionjson
  local content
  content=$(cat "${logger}.json")
  assert_contains "$content" '"id": "1"' "JSON should contain section id"
  assert_contains "$content" "Host Configuration" "JSON should contain section desc"
  assert_contains "$content" '"id": "1.1"' "JSON should contain test id"
  assert_contains "$content" '"result": "PASS"' "JSON should contain result"
  _teardown
}

test_log_to_json_with_details() {
  _setup
  beginjson "1.6.0" "1700000000"
  startsectionjson "2" "Docker daemon"
  starttestjson "2.1" "Check log level"
  log_to_json "WARN" "log level is debug"
  local content
  content=$(cat "${logger}.json")
  assert_contains "$content" '"result": "WARN"' "Should contain WARN result"
  assert_contains "$content" '"details": "log level is debug"' "Should contain details"
  _teardown
}
