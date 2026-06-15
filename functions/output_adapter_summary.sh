#!/bin/bash
# --------------------------------------------------------------------------------------------
# Summary Output Adapter
#
# Suppresses per-check display.  Records all results in memory and emits a single
# machine-readable report when summary_print is called at the end of the run.
#
# Output format (tab-delimited, parseable with awk/cut/grep):
#
#   # Docker Bench for Security — Summary
#   PASS    1.1 - Ensure separate partition for /tmp
#   WARN    2.1 - Ensure logging level is set to info
#   INFO    3.1 - File not found
#   NOTE    4.1 - Manual review needed
#   ...
#   # Summary
#   # Passed: 10
#   # Failed: 3
#   # Info: 2
#   # Skipped: 1
#   # Total checks: 16
#   # Score: 7
#
# CI integration examples:
#   awk -F'\t' '/^WARN/ {print $2}'   # list failed check messages
#   grep -c '^WARN'                     # count failures
#   grep '^# Failed:' | awk '{print $3}'  # extract failure count
# --------------------------------------------------------------------------------------------

# Display functions are no-ops in summary mode.
_display_logit() { :; }
_display_pass()  { :; }
_display_warn()  { :; }
_display_info()  { :; }
_display_note()  { :; }

# Emit the accumulated summary report to stdout and the log file.
summary_print() {
  local _pass=0 _fail=0 _info=0 _skip=0

  for r in "${_SUMMARY_RESULTS[@]}"; do
    case "$r" in
      PASS*) _pass=$((_pass + 1)) ;;
      WARN*) _fail=$((_fail + 1)) ;;
      INFO*) _info=$((_info + 1)) ;;
      NOTE*) _skip=$((_skip + 1)) ;;
    esac
  done

  {
    printf "# Docker Bench for Security — Summary\n"
    for r in "${_SUMMARY_RESULTS[@]}"; do
      printf "%b\n" "$r"
    done
    printf "# Summary\n"
    printf "# Passed: %d\n" "$_pass"
    printf "# Failed: %d\n" "$_fail"
    printf "# Info: %d\n" "$_info"
    printf "# Skipped: %d\n" "$_skip"
    printf "# Total checks: %d\n" "$totalChecks"
    printf "# Score: %d\n" "$currentScore"
  } | tee -a "$logger"
}
