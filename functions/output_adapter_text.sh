#!/bin/bash
# --------------------------------------------------------------------------------------------
# Text Output Adapter
#
# Displays check results in the traditional colored [PASS]/[WARN]/[INFO]/[NOTE] format.
# Each function writes to both stdout and the log file, preserving backward compatibility
# with the original docker-bench-security output.
#
# Recording into _SUMMARY_RESULTS is handled by the scoring section in output_lib.sh,
# not by the display functions — this avoids double-counting.
# --------------------------------------------------------------------------------------------

_display_logit() {
  printf "%b\n" "$1" | tee -a "$logger"
}

_display_pass() {
  printf "%b\n" "${bldgrn}[PASS]${txtrst} $1" | tee -a "$logger"
}

_display_warn() {
  printf "%b\n" "${bldred}[WARN]${txtrst} $1" | tee -a "$logger"
}

_display_info() {
  printf "%b\n" "${bldblu}[INFO]${txtrst} $1" | tee -a "$logger"
}

_display_note() {
  printf "%b\n" "${bldylw}[NOTE]${txtrst} $1" | tee -a "$logger"
}

# Text mode: summary_print is a no-op; score is already printed by main().
summary_print() {
  :
}
