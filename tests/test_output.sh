#!/bin/bash
# --------------------------------------------------------------------------------------------
# Test suite for the output adapter layer
#
# Covers:
#   1. Text output backward compatibility (PASS/WARN/INFO/NOTE format, scoring)
#   2. Summary mode (machine-readable report, per-check silence)
#   3. Failure / warn counting (scored warn decrements, scored pass increments)
#   4. Empty results (no checks → zero counters, valid summary)
#   5. JSON output independence from adapter mode
#
# Run:  bash tests/test_output.sh
# --------------------------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBEXEC="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_RUN=0

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------

# Capture stdout to a file WITHOUT a subshell, so shell-variable mutations
# (totalChecks, currentScore, _SUMMARY_RESULTS) are visible in the caller.
_capture_file=""
capture() {
  _capture_file="$(mktemp)"
  # Redirect fd 1 to the file; the function runs in the current shell.
  eval '"$@"' > "$_capture_file"
}
captured() { cat "$_capture_file"; rm -f "$_capture_file"; }

setup() {
  local test_dir
  test_dir="$(mktemp -d)"
  logger="${test_dir}/test.log"
  touch "$logger"
  nocolor="nocolor"
  totalChecks=0
  currentScore=0
  limit=0
  printremediation="0"
  globalRemediation=""
  _SUMMARY_RESULTS=()
  SEP=
  SSEP=
}

teardown() {
  rm -rf "$(dirname "$logger")"
  rm -f "$_capture_file"
}

run_test() {
  local test_name="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  setup
  if "$test_name"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}  PASS${NC}  %s\n" "$test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}  FAIL${NC}  %s\n" "$test_name"
  fi
  teardown
}

assert_contains() {
  if ! printf '%s' "$1" | grep -qF "$2"; then
    printf "    assert_contains FAILED: '%s' not found (%s)\n" "$2" "$3"
    printf "    --- output ---\n%s\n    --- end ---\n" "$1"
    return 1
  fi
}

assert_not_contains() {
  if printf '%s' "$1" | grep -qF "$2"; then
    printf "    assert_not_contains FAILED: '%s' found but should be absent (%s)\n" "$2" "$3"
    return 1
  fi
}

assert_equals() {
  if [ "$1" != "$2" ]; then
    printf "    assert_equals FAILED: expected '%s', got '%s' (%s)\n" "$2" "$1" "$3"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# 1. Text output — backward compatibility
# ---------------------------------------------------------------------------

test_text_pass_scored() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture pass -s '1.1 - Ensure separate partition for /tmp'
  local out; out="$(captured)"
  assert_contains "$out" "[PASS]" "PASS tag" &&
  assert_contains "$out" "1.1 - Ensure separate partition for /tmp" "message" &&
  assert_equals "$totalChecks" "1" "totalChecks" &&
  assert_equals "$currentScore" "1" "currentScore"
}

test_text_pass_counted() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture pass -c '2.1 - Some counted pass'
  local out; out="$(captured)"
  assert_contains "$out" "[PASS]" "PASS tag" &&
  assert_equals "$totalChecks" "1" "totalChecks" &&
  assert_equals "$currentScore" "0" "score should be 0 for counted-only"
}

test_text_pass_plain() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture pass 'Detail line for pass'
  local out; out="$(captured)"
  assert_contains "$out" "[PASS]" "PASS tag" &&
  assert_contains "$out" "Detail line for pass" "detail" &&
  assert_equals "$totalChecks" "0" "plain pass must not count" &&
  assert_equals "$currentScore" "0" "plain pass must not score"
}

test_text_warn_scored() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture warn -s '3.2 - File permissions too open'
  local out; out="$(captured)"
  assert_contains "$out" "[WARN]" "WARN tag" &&
  assert_contains "$out" "3.2 - File permissions too open" "message" &&
  assert_equals "$totalChecks" "1" "totalChecks" &&
  assert_equals "$currentScore" "-1" "scored warn must decrement"
}

test_text_warn_plain() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture warn '     * Wrong ownership for /etc/docker/daemon.json'
  local out; out="$(captured)"
  assert_contains "$out" "[WARN]" "WARN tag" &&
  assert_contains "$out" "Wrong ownership" "detail" &&
  assert_equals "$totalChecks" "0" "plain warn must not count" &&
  assert_equals "$currentScore" "0" "plain warn must not score"
}

test_text_info_counted() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture info -c '4.1 - Image check not applicable'
  local out; out="$(captured)"
  assert_contains "$out" "[INFO]" "INFO tag" &&
  assert_equals "$totalChecks" "1" "totalChecks"
}

test_text_info_plain() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture info '     * File not found'
  local out; out="$(captured)"
  assert_contains "$out" "[INFO]" "INFO tag" &&
  assert_contains "$out" "File not found" "detail" &&
  assert_equals "$totalChecks" "0" "plain info must not count"
}

test_text_note_counted() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture note -c '5.1 - Manual check'
  local out; out="$(captured)"
  assert_contains "$out" "[NOTE]" "NOTE tag" &&
  assert_equals "$totalChecks" "1" "totalChecks"
}

test_text_note_plain() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture note 'Some annotation'
  local out; out="$(captured)"
  assert_contains "$out" "[NOTE]" "NOTE tag" &&
  assert_equals "$totalChecks" "0" "plain note must not count"
}

test_text_section_header_no_count() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  capture info 'Section 3 - Docker daemon configuration files'
  local out; out="$(captured)"
  assert_contains "$out" "[INFO]" "INFO tag" &&
  assert_contains "$out" "Section 3" "header text" &&
  assert_equals "$totalChecks" "0" "section header must not count"
}

# ---------------------------------------------------------------------------
# 2. Summary mode — machine-readable output
# ---------------------------------------------------------------------------

test_summary_pass_recorded() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  pass -s '1.1 - Ensure separate partition' >/dev/null
  assert_equals "${#_SUMMARY_RESULTS[@]}" "1" "one result recorded" &&
  assert_contains "${_SUMMARY_RESULTS[0]}" "PASS" "PASS status" &&
  assert_contains "${_SUMMARY_RESULTS[0]}" "1.1" "check id in message"
}

test_summary_warn_recorded() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  warn -s '2.1 - Logging not set to info' >/dev/null
  assert_equals "${#_SUMMARY_RESULTS[@]}" "1" "one result recorded" &&
  assert_contains "${_SUMMARY_RESULTS[0]}" "WARN" "WARN status"
}

test_summary_info_counted_recorded() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  info -c '3.1 - Not applicable' >/dev/null
  assert_equals "${#_SUMMARY_RESULTS[@]}" "1" "one result recorded" &&
  assert_contains "${_SUMMARY_RESULTS[0]}" "INFO" "INFO status"
}

test_summary_note_counted_recorded() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  note -c '4.1 - Manual review needed' >/dev/null
  assert_equals "${#_SUMMARY_RESULTS[@]}" "1" "one result recorded" &&
  assert_contains "${_SUMMARY_RESULTS[0]}" "NOTE" "NOTE status"
}

test_summary_plain_calls_not_recorded() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  pass 'detail' >/dev/null
  warn 'detail' >/dev/null
  info 'header' >/dev/null
  note 'annotation' >/dev/null
  assert_equals "${#_SUMMARY_RESULTS[@]}" "0" "plain calls must not be recorded"
}

test_summary_per_check_silent() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  local out
  out="$(pass -s '1.1 - Some check' 2>/dev/null)"
  assert_equals "$out" "" "pass -s must produce no stdout in summary mode" &&
  out="$(warn -s '2.1 - Some failure' 2>/dev/null)" &&
  assert_equals "$out" "" "warn -s must produce no stdout in summary mode" &&
  out="$(info -c '3.1 - Not applicable' 2>/dev/null)" &&
  assert_equals "$out" "" "info -c must produce no stdout in summary mode"
}

test_summary_logit_silent() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  local out
  out="$(logit 'Section A - Check results' 2>/dev/null)"
  assert_equals "$out" "" "logit must produce no stdout in summary mode"
}

test_summary_print_format() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  pass -s '1.1 - Ensure separate partition' >/dev/null
  warn -s '2.1 - Logging level not info' >/dev/null
  info -c '3.1 - Not applicable' >/dev/null
  note -c '4.1 - Manual review' >/dev/null

  local summary_out
  summary_out="$(summary_print 2>/dev/null)"

  # Header present
  assert_contains "$summary_out" "Docker Bench for Security" "header" &&
  # Each result status present
  assert_contains "$summary_out" "PASS" "PASS line" &&
  assert_contains "$summary_out" "WARN" "WARN line" &&
  assert_contains "$summary_out" "INFO" "INFO line" &&
  assert_contains "$summary_out" "NOTE" "NOTE line" &&
  # Summary section
  assert_contains "$summary_out" "# Summary" "summary header" &&
  assert_contains "$summary_out" "# Passed: 1" "passed count" &&
  assert_contains "$summary_out" "# Failed: 1" "failed count" &&
  assert_contains "$summary_out" "# Info: 1" "info count" &&
  assert_contains "$summary_out" "# Skipped: 1" "skipped count" &&
  assert_contains "$summary_out" "# Total checks: 4" "total" &&
  assert_contains "$summary_out" "# Score: 0" "score (1-1=0)"
}

test_summary_print_parseable() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  pass -s '1.1 - First check' >/dev/null
  warn -s '2.1 - Second check' >/dev/null

  local summary_out
  summary_out="$(summary_print 2>/dev/null)"

  # grep can count WARN lines
  local fail_count
  fail_count="$(printf '%s\n' "$summary_out" | grep -c '^WARN' || true)"
  assert_equals "$fail_count" "1" "grep counts WARN lines" &&
  # awk can extract message from tab-delimited fields (field 2)
  local first_msg
  first_msg="$(printf '%s\n' "$summary_out" | awk -F'\t' '/^PASS/{print $2}')"
  assert_contains "$first_msg" "1.1" "awk extracts check id from PASS line"
}

test_summary_scoring_correct() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  pass -s 'check 1' >/dev/null   # +1 score, +1 checks
  pass -s 'check 2' >/dev/null   # +1 score, +1 checks
  pass -s 'check 3' >/dev/null   # +1 score, +1 checks
  warn -s 'check 4' >/dev/null   # -1 score, +1 checks
  warn -s 'check 5' >/dev/null   # -1 score, +1 checks
  info -c 'check 6' >/dev/null   #  0 score, +1 checks

  assert_equals "$totalChecks" "6" "totalChecks" &&
  assert_equals "$currentScore" "1" "score: 3-2=1" &&
  assert_equals "${#_SUMMARY_RESULTS[@]}" "6" "all 6 recorded"
}

# ---------------------------------------------------------------------------
# 3. Failure / warn counting
# ---------------------------------------------------------------------------

test_failure_counting_mixed() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"

  pass -s 'scored pass 1' >/dev/null
  pass -s 'scored pass 2' >/dev/null
  pass -c 'counted pass' >/dev/null
  warn -s 'scored warn 1' >/dev/null
  warn -s 'scored warn 2' >/dev/null
  warn -s 'scored warn 3' >/dev/null
  warn 'plain warn detail' >/dev/null
  info -c 'counted info' >/dev/null
  info 'plain info detail' >/dev/null
  note -c 'counted note' >/dev/null
  pass 'plain pass detail' >/dev/null

  # totalChecks: 2 (pass -s) + 1 (pass -c) + 3 (warn -s) + 1 (info -c) + 1 (note -c) = 8
  assert_equals "$totalChecks" "8" "totalChecks counts all scored/counted calls" &&
  # currentScore: +2 (pass -s) -3 (warn -s) = -1
  assert_equals "$currentScore" "-1" "score = scored_passes - scored_warns"
}

test_failure_counting_summary_mode() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"

  pass -s 'ok 1' >/dev/null
  warn -s 'fail 1' >/dev/null
  warn -s 'fail 2' >/dev/null
  pass -c 'info pass' >/dev/null

  assert_equals "$totalChecks" "4" "totalChecks" &&
  assert_equals "$currentScore" "-1" "score: 1-2=-1" &&
  # Verify summary report captures correct counts
  local summary_out
  summary_out="$(summary_print 2>/dev/null)"
  # pass -s and pass -c both record as PASS → Passed: 2
  assert_contains "$summary_out" "# Passed: 2" "two passes in summary" &&
  assert_contains "$summary_out" "# Failed: 2" "two failures in summary"
}

# ---------------------------------------------------------------------------
# 4. Empty results
# ---------------------------------------------------------------------------

test_empty_text_no_checks() {
  OUTPUT_MODE="text"
  . "$LIBEXEC/functions/output_lib.sh"
  assert_equals "$totalChecks" "0" "totalChecks zero" &&
  assert_equals "$currentScore" "0" "score zero"
}

test_empty_summary_print() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  local summary_out
  summary_out="$(summary_print 2>/dev/null)"
  assert_contains "$summary_out" "# Passed: 0" "zero passed" &&
  assert_contains "$summary_out" "# Failed: 0" "zero failed" &&
  assert_contains "$summary_out" "# Info: 0" "zero info" &&
  assert_contains "$summary_out" "# Skipped: 0" "zero skipped" &&
  assert_contains "$summary_out" "# Total checks: 0" "zero total" &&
  assert_contains "$summary_out" "# Score: 0" "zero score" &&
  assert_equals "${#_SUMMARY_RESULTS[@]}" "0" "no results recorded"
}

test_empty_summary_print_has_header() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  local summary_out
  summary_out="$(summary_print 2>/dev/null)"
  assert_contains "$summary_out" "Docker Bench for Security" "header still present" &&
  assert_contains "$summary_out" "# Summary" "summary section still present"
}

# ---------------------------------------------------------------------------
# 5. JSON output independence
# ---------------------------------------------------------------------------

test_json_output_independent_of_mode() {
  OUTPUT_MODE="summary"
  . "$LIBEXEC/functions/output_lib.sh"
  beginjson "1.6.0" "1000" >/dev/null 2>&1
  startsectionjson "1" "Host Configuration" >/dev/null 2>&1
  starttestjson "1.1" "Ensure separate partition" >/dev/null 2>&1
  log_to_json "PASS" >/dev/null 2>&1
  endsectionjson >/dev/null 2>&1
  endjson "1" "1" "1001" >/dev/null 2>&1

  local json_content
  json_content="$(cat "${logger}.json")"
  assert_contains "$json_content" "dockerbenchsecurity" "JSON has root key" &&
  assert_contains "$json_content" "\"result\": \"PASS\"" "JSON has result" &&
  assert_contains "$json_content" "\"checks\": 1" "JSON has checks total"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

printf "\n=== Docker Bench Security — Output Adapter Tests ===\n\n"

# 1. Text backward compatibility
printf "Text output (backward compatibility):\n"
run_test test_text_pass_scored
run_test test_text_pass_counted
run_test test_text_pass_plain
run_test test_text_warn_scored
run_test test_text_warn_plain
run_test test_text_info_counted
run_test test_text_info_plain
run_test test_text_note_counted
run_test test_text_note_plain
run_test test_text_section_header_no_count

# 2. Summary mode
printf "\nSummary mode (machine-readable):\n"
run_test test_summary_pass_recorded
run_test test_summary_warn_recorded
run_test test_summary_info_counted_recorded
run_test test_summary_note_counted_recorded
run_test test_summary_plain_calls_not_recorded
run_test test_summary_per_check_silent
run_test test_summary_logit_silent
run_test test_summary_print_format
run_test test_summary_print_parseable
run_test test_summary_scoring_correct

# 3. Failure counting
printf "\nFailure / warn counting:\n"
run_test test_failure_counting_mixed
run_test test_failure_counting_summary_mode

# 4. Empty results
printf "\nEmpty results:\n"
run_test test_empty_text_no_checks
run_test test_empty_summary_print
run_test test_empty_summary_print_has_header

# 5. JSON independence
printf "\nJSON output independence:\n"
run_test test_json_output_independent_of_mode

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

printf "\n--- Results: %d passed, %d failed, %d total ---\n" \
  "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_RUN"

if [ "$TESTS_FAILED" -gt 0 ]; then
  printf "${RED}SOME TESTS FAILED${NC}\n"
  exit 1
fi
printf "${GREEN}ALL TESTS PASSED${NC}\n"
exit 0
