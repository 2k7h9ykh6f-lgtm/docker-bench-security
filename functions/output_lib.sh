#!/bin/bash
# --------------------------------------------------------------------------------------------
# Output Library — Adapter Dispatcher
#
# Public API (called by test scripts):
#   pass  [-s|-c] "message"   Scored pass (+1 score, +1 checks) or counted pass (+1 checks)
#   warn  [-s]     "message"   Scored warn (-1 score, +1 checks) or plain detail line
#   info  [-c]     "message"   Counted info (+1 checks) or plain info
#   note  [-c]     "message"   Counted note (+1 checks) or plain note
#   logit          "message"   Raw output (section headers, free-form text)
#   yell           "message"   Banner/header to stdout only (never logged)
#   summary_print              Emit machine-readable summary (no-op in text mode)
#
# Output modes (set via OUTPUT_MODE before sourcing):
#   text    — backward-compatible coloured [PASS]/[WARN]/[INFO]/[NOTE] lines
#   summary — silent per-check; single machine-readable report via summary_print
#
# JSON output (beginjson/endjson/startsectionjson/.../logcheckresult) writes to
# $logger.json independently of the stdout adapter and is NOT affected by OUTPUT_MODE.
# --------------------------------------------------------------------------------------------

# ---- Adapter selection --------------------------------------------------------

OUTPUT_MODE="${OUTPUT_MODE:-text}"

_record_result() {
  _SUMMARY_RESULTS+=("${1}	${2}")
}

case "$OUTPUT_MODE" in
  summary) . "$LIBEXEC/functions/output_adapter_summary.sh" ;;
  *)       . "$LIBEXEC/functions/output_adapter_text.sh"     ;;
esac

# ---- Colour definitions (used by text adapter) --------------------------------

bldred='\033[1;31m' # Bold Red
bldgrn='\033[1;32m' # Bold Green
bldblu='\033[1;34m' # Bold Blue
bldylw='\033[1;33m' # Bold Yellow
txtrst='\033[0m'

if [ -n "$nocolor" ] && [ "$nocolor" = "nocolor" ]; then
  bldred=''
  bldgrn=''
  bldblu=''
  bldylw=''
  txtrst=''
fi

# ---- Public API — scoring + adapter dispatch ----------------------------------

logit() {
  _display_logit "$1"
}

info() {
  local infoCountCheck
  local OPTIND c
  while getopts c args; do
    case $args in
    c) infoCountCheck="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$infoCountCheck" = "true" ]; then
    _record_result "INFO" "$2"
    _display_info "$2"
    totalChecks=$((totalChecks + 1))
    return
  fi
  _display_info "$1"
}

pass() {
  local passScored
  local passCountCheck
  local OPTIND s c
  while getopts sc args; do
    case $args in
    s) passScored="true" ;;
    c) passCountCheck="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$passScored" = "true" ] || [ "$passCountCheck" = "true" ]; then
    _record_result "PASS" "$2"
    _display_pass "$2"
    totalChecks=$((totalChecks + 1))
  else
    _display_pass "$1"
  fi
  if [ "$passScored" = "true" ]; then
    currentScore=$((currentScore + 1))
  fi
}

warn() {
  local warnScored
  local OPTIND s
  while getopts s args; do
    case $args in
    s) warnScored="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$warnScored" = "true" ]; then
    _record_result "WARN" "$2"
    _display_warn "$2"
    totalChecks=$((totalChecks + 1))
    currentScore=$((currentScore - 1))
    return
  fi
  _display_warn "$1"
}

note() {
  local noteCountCheck
  local OPTIND c
  while getopts c args; do
    case $args in
    c) noteCountCheck="true" ;;
    *) exit 1 ;;
    esac
  done
  if [ "$noteCountCheck" = "true" ]; then
    _record_result "NOTE" "$2"
    _display_note "$2"
    totalChecks=$((totalChecks + 1))
    return
  fi
  _display_note "$1"
}

yell() {
  printf "%b\n" "${bldylw}$1${txtrst}\n"
}

# ---- JSON output (unchanged — writes to $logger.json, independent of mode) ----

beginjson() {
  printf "{\n  \"dockerbenchsecurity\": \"%s\",\n  \"start\": %s,\n  \"tests\": [" "$1" "$2" | tee "$logger.json" 2>/dev/null 1>&2
}

endjson() {
  printf "\n  ],\n  \"checks\": %s,\n  \"score\": %s,\n  \"end\": %s\n}" "$1" "$2" "$3" | tee -a "$logger.json" 2>/dev/null 1>&2
}

logjson() {
  printf "\n  \"%s\": \"%s\"," "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
}

SSEP=
SEP=
startsectionjson() {
  printf "%s\n    {\n      \"id\": \"%s\",\n      \"desc\": \"%s\",\n      \"results\": [" "$SSEP" "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
  SEP=
  SSEP=","
}

endsectionjson() {
  printf "\n      ]\n    }" | tee -a "$logger.json" 2>/dev/null 1>&2
}

starttestjson() {
  printf "%s\n        {\n          \"id\": \"%s\",\n          \"desc\": \"%s\",\n          " "$SEP" "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
  SEP=","
}

log_to_json() {
  if [ $# -eq 1 ]; then
    printf "\"result\": \"%s\"" "$1" | tee -a "$logger.json" 2>/dev/null 1>&2
    return
  fi
  if [ $# -eq 2 ] && [ $# -ne 1 ]; then
    # Result also contains details
    printf "\"result\": \"%s\",\n          \"details\": \"%s\"" "$1" "$2" | tee -a "$logger.json" 2>/dev/null 1>&2
    return
  fi
  # Result also includes details and a list of items. Add that directly to details and to an array property "items"
  # Also limit the number of items to $limit, if $limit is non-zero
  truncItems=$3
  if [ "$limit" != 0 ]; then
    truncItems=""
    ITEM_COUNT=0
    for item in $3; do
      truncItems="$truncItems $item"
      ITEM_COUNT=$((ITEM_COUNT + 1));
      if [ "$ITEM_COUNT" == "$limit" ]; then
        truncItems="$truncItems (truncated)"
        break;
      fi
    done
  fi
  itemsJson=$(printf "[\n            "; ISEP=""; ITEMCOUNT=0; for item in $truncItems; do printf "%s\"%s\"" "$ISEP" "$item"; ISEP=","; done; printf "\n          ]")
  printf "\"result\": \"%s\",\n          \"details\": \"%s: %s\",\n          \"items\": %s" "$1" "$2" "$truncItems" "$itemsJson" | tee -a "$logger.json" 2>/dev/null 1>&2
}

logcheckresult() {
  # Log to JSON
  log_to_json "$@"

  # Log remediation measure to JSON
  if [ -n "$remediation" ] && [ "$1" != "PASS" ] && [ "$printremediation" = "1" ]; then
    printf ",\n          \"remediation\": \"%s\"" "$remediation" | tee -a "$logger.json" 2>/dev/null 1>&2
    if [ -n "$remediationImpact" ]; then
      printf ",\n          \"remediation-impact\": \"%s\"" "$remediationImpact" | tee -a "$logger.json" 2>/dev/null 1>&2
    fi
  fi
  printf "\n        }" | tee -a "$logger.json" 2>/dev/null 1>&2

  # Save remediation measure for print log to stdout
  if [ -n "$remediation" ] && [ "$1" != "PASS" ]; then
    if [ -n "${checkHeader}" ]; then
      if [ -n "${addSpaceHeader}" ]; then
        globalRemediation="${globalRemediation}\n"
      fi
      globalRemediation="${globalRemediation}\n${bldblu}[INFO]${txtrst} ${checkHeader}"
      checkHeader=""
      addSpaceHeader="1"
    fi
    globalRemediation="${globalRemediation}\n${bldblu}[INFO]${txtrst} ${id} - ${remediation}"
    if [ -n "${remediationImpact}" ]; then
      globalRemediation="${globalRemediation} Remediation Impact: ${remediationImpact}"
    fi
  fi
}
