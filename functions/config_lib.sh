#!/bin/bash
# --------------------------------------------------------------------------------------------
# config_lib.sh - Unified configuration loading for Docker Bench for Security
#
# Priority (lowest → highest):
#   1. Hardcoded defaults
#   2. Config file  (docker-bench-security.conf or path in DBS_CONFIG_FILE)
#   3. Environment variables (DBS_* prefix)
#   4. CLI arguments (getopts)
#
# Each resolved value is paired with a source label so callers can report
# where a setting came from when diagnosing failures.
# --------------------------------------------------------------------------------------------

# --- Known configuration keys ------------------------------------------------
# This is the single source of truth for valid keys.
# Format: internal_var_name
DBS_KNOWN_KEYS="nocolor logger limit printremediation dockertrustusers check checkexclude include exclude labels"

# --- Source tracking ---------------------------------------------------------
# For each key we store __cfg_src_<key> = "default"|"file:<path>"|"env"|"cli"
# Using plain variables instead of associative arrays for maximum portability.

_cfg_set_source() {
  local key="$1" src="$2"
  eval "__cfg_src_${key}=\"${src}\""
}

cfg_get_source() {
  local key="$1"
  eval "printf '%s' \"\${__cfg_src_${key}:-unknown}\""
}

# --- Default values ----------------------------------------------------------
_cfg_apply_defaults() {
  # Only set if the variable is currently unset/empty (preserves pre-existing exports)
  : "${nocolor:=}"
  : "${logger:=log/${myname}.log}"
  : "${limit:=0}"
  : "${printremediation:=0}"
  : "${dockertrustusers:=}"
  : "${check:=}"
  : "${checkexclude:=}"
  : "${include:=}"
  : "${exclude:=}"
  : "${labels:=}"

  for _k in $DBS_KNOWN_KEYS; do
    _cfg_set_source "$_k" "default"
  done
}

# --- Config file loading -----------------------------------------------------
# Format: KEY=VALUE, one per line. Lines starting with # are comments.
# Supported keys (mapped to internal variable names):
#   NO_COLOR          → nocolor
#   LOG_FILE          → logger
#   LIMIT             → limit
#   PRINT_REMEDIATION → printremediation
#   TRUSTED_USERS     → dockertrustusers
#   CHECK             → check
#   CHECK_EXCLUDE     → checkexclude
#   INCLUDE           → include
#   EXCLUDE           → exclude
#   LABELS            → labels

# Mapping from config-file key names to internal variable names
_cfg_file_key_to_var() {
  case "$1" in
    NO_COLOR)          echo "nocolor" ;;
    LOG_FILE)          echo "logger" ;;
    LIMIT)             echo "limit" ;;
    PRINT_REMEDIATION) echo "printremediation" ;;
    TRUSTED_USERS)     echo "dockertrustusers" ;;
    CHECK)             echo "check" ;;
    CHECK_EXCLUDE)     echo "checkexclude" ;;
    INCLUDE)           echo "include" ;;
    EXCLUDE)           echo "exclude" ;;
    LABELS)            echo "labels" ;;
    *)                 return 1 ;;  # unknown key
  esac
}

_cfg_load_file() {
  local cfg_file="$1"
  [ -f "$cfg_file" ] || return 0

  local line_no=0
  local unknown_keys=""
  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))

    # Strip leading/trailing whitespace
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Skip empty lines and comments
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac

    # Parse KEY=VALUE
    if ! printf '%s' "$line" | grep -q '='; then
      printf "config error: %s:%d: invalid line (no '='): %s\n" "$cfg_file" "$line_no" "$line" >&2
      return 1
    fi

    local key val
    key="$(printf '%s' "$line" | cut -d'=' -f1)"
    val="$(printf '%s' "$line" | cut -d'=' -f2-)"
    # Strip surrounding quotes from value
    val="$(printf '%s' "$val" | sed 's/^["'\''"]//;s/["'\''"]$//')"

    local varname
    if ! varname="$(_cfg_file_key_to_var "$key")"; then
      unknown_keys="${unknown_keys}  - ${key} (line ${line_no})\n"
      continue
    fi

    eval "${varname}=\"\${val}\""
    _cfg_set_source "$varname" "file:${cfg_file}"
  done < "$cfg_file"

  if [ -n "$unknown_keys" ]; then
    printf "config error: unknown key(s) in %s:\n%b" "$cfg_file" "$unknown_keys" >&2
    return 1
  fi

  return 0
}

# --- Environment variable loading -------------------------------------------
# DBS_* prefix. Only override if the env var is set and non-empty.
_cfg_load_env() {
  local mappings="
    DBS_NO_COLOR:nocolor
    DBS_LOG_FILE:logger
    DBS_LIMIT:limit
    DBS_PRINT_REMEDIATION:printremediation
    DBS_TRUSTED_USERS:dockertrustusers
    DBS_CHECK:check
    DBS_CHECK_EXCLUDE:checkexclude
    DBS_INCLUDE:include
    DBS_EXCLUDE:exclude
    DBS_LABELS:labels
  "

  for mapping in $mappings; do
    local env_key varname env_val
    env_key="$(printf '%s' "$mapping" | cut -d: -f1)"
    varname="$(printf '%s' "$mapping" | cut -d: -f2)"

    eval "env_val=\"\${${env_key}:-}\""
    if [ -n "$env_val" ]; then
      eval "${varname}=\"\${env_val}\""
      _cfg_set_source "$varname" "env:${env_key}"
    fi
  done
}

# --- CLI flag tracking -------------------------------------------------------
# Called after getopts to mark CLI-provided values.
_cfg_mark_cli() {
  # Map: variable name → was it set by CLI?
  # We check the flag variables that getopts populates.
  if [ -n "${_cli_nocolor:-}" ];          then _cfg_set_source "nocolor" "cli:-b"; fi
  if [ -n "${_cli_logger:-}" ];           then _cfg_set_source "logger" "cli:-l"; fi
  if [ -n "${_cli_limit:-}" ];            then _cfg_set_source "limit" "cli:-n"; fi
  if [ -n "${_cli_printremediation:-}" ]; then _cfg_set_source "printremediation" "cli:-p"; fi
  if [ -n "${_cli_dockertrustusers:-}" ]; then _cfg_set_source "dockertrustusers" "cli:-u"; fi
  if [ -n "${_cli_check:-}" ];            then _cfg_set_source "check" "cli:-c"; fi
  if [ -n "${_cli_checkexclude:-}" ];     then _cfg_set_source "checkexclude" "cli:-e"; fi
  if [ -n "${_cli_include:-}" ];          then _cfg_set_source "include" "cli:-i"; fi
  if [ -n "${_cli_exclude:-}" ];          then _cfg_set_source "exclude" "cli:-x"; fi
  if [ -n "${_cli_labels:-}" ];           then _cfg_set_source "labels" "cli:-t"; fi
}

# --- Configuration summary ---------------------------------------------------
cfg_print_summary() {
  printf "%b\n" "${bldylw}Configuration summary:${txtrst}"
  for _k in $DBS_KNOWN_KEYS; do
    local val src
    eval "val=\"\${${_k}:-}\""
    src="$(cfg_get_source "$_k")"
    # Mask empty values for readability
    [ -z "$val" ] && val="(empty)"
    printf "  %-22s = %-40s  [%s]\n" "$_k" "$val" "$src"
  done
}

# --- Main entry point --------------------------------------------------------
# load_config <config_file_path>
#
# Call sequence:
#   1. Apply hardcoded defaults
#   2. Load config file (if exists)
#   3. Load environment variables
#   4. Apply CLI overrides (already parsed into variables by getopts)
#   5. Mark CLI sources
#
# The config file path can be overridden via DBS_CONFIG_FILE env var.
# If no path is given, searches:
#   - ./docker-bench-security.conf
#   - /etc/docker-bench-security.conf

load_config() {
  local cfg_file="${1:-}"

  # Step 1: defaults
  _cfg_apply_defaults

  # Step 2: config file
  # Allow DBS_CONFIG_FILE env to specify the path
  if [ -z "$cfg_file" ]; then
    cfg_file="${DBS_CONFIG_FILE:-}"
  fi
  if [ -z "$cfg_file" ]; then
    # Search standard locations
    if [ -f "./docker-bench-security.conf" ]; then
      cfg_file="./docker-bench-security.conf"
    elif [ -f "/etc/docker-bench-security.conf" ]; then
      cfg_file="/etc/docker-bench-security.conf"
    fi
  fi
  if [ -n "$cfg_file" ]; then
    if ! _cfg_load_file "$cfg_file"; then
      return 1
    fi
  fi

  # Step 3: environment variables
  _cfg_load_env

  # Step 4: CLI overrides are already applied by getopts before load_config is called.
  # Step 5: mark CLI sources
  _cfg_mark_cli

  return 0
}
