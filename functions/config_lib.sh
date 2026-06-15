#!/bin/bash

# --------------------------------------------------------------------------------------------
# Configuration loading library for Docker Bench for Security
#
# Loading order (lowest to highest priority):
#   1. Built-in defaults
#   2. Config file (./docker-bench-security.conf or /etc/docker-bench-security.conf)
#   3. Environment variables (DBS_* prefix)
#   4. CLI flags
#
# Each variable VAR gets a companion VAR_src tracking where the value came from:
#   "default", "config:<filepath>", "env:<ENVVAR>", "cli:<flag>"
# --------------------------------------------------------------------------------------------

# --- Internal helpers ---

_config_valid_keys() {
  printf "log_file no_color limit print_remediation trust_users check check_exclude include exclude labels"
}

_config_is_valid_key() {
  for _civ_k in $(_config_valid_keys); do
    if [ "$1" = "$_civ_k" ]; then
      return 0
    fi
  done
  return 1
}

_config_normalize_bool() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    true|yes|1)  printf "true"  ; return 0 ;;
    false|no|0)  printf "false" ; return 0 ;;
    *)           return 1 ;;
  esac
}

_config_set() {
  _cs_var="$1"
  _cs_val="$2"
  _cs_src="$3"
  eval "${_cs_var}=\"\${_cs_val}\""
  eval "${_cs_var}_src=\"\${_cs_src}\""
}

_config_map_key_to_var() {
  case "$1" in
    log_file)          printf "logger" ;;
    no_color)          printf "nocolor" ;;
    limit)             printf "limit" ;;
    print_remediation) printf "printremediation" ;;
    trust_users)       printf "dockertrustusers" ;;
    check)             printf "check" ;;
    check_exclude)     printf "checkexclude" ;;
    include)           printf "include" ;;
    exclude)           printf "exclude" ;;
    labels)            printf "labels" ;;
    *)                 return 1 ;;
  esac
}

_config_map_key_to_env() {
  case "$1" in
    log_file)          printf "DBS_LOG_FILE" ;;
    no_color)          printf "DBS_NO_COLOR" ;;
    limit)             printf "DBS_LIMIT" ;;
    print_remediation) printf "DBS_PRINT_REMEDIATION" ;;
    trust_users)       printf "DBS_TRUST_USERS" ;;
    check)             printf "DBS_CHECK" ;;
    check_exclude)     printf "DBS_CHECK_EXCLUDE" ;;
    include)           printf "DBS_INCLUDE" ;;
    exclude)           printf "DBS_EXCLUDE" ;;
    labels)            printf "DBS_LABELS" ;;
    *)                 return 1 ;;
  esac
}

_config_convert_bool_for_var() {
  case "$1" in
    nocolor)
      if [ "$2" = "true" ]; then printf "nocolor"; else printf ""; fi
      ;;
    printremediation)
      if [ "$2" = "true" ]; then printf "1"; else printf "0"; fi
      ;;
    *)
      printf '%s' "$2"
      ;;
  esac
}

_config_is_bool_var() {
  case "$1" in
    nocolor|printremediation) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Public API ---

config_set_defaults() {
  _config_set logger   "log/${myname}.log" "default"
  _config_set nocolor  ""                  "default"
  _config_set limit    "0"                 "default"
  _config_set printremediation "0"         "default"
  _config_set dockertrustusers ""          "default"
  _config_set check         ""             "default"
  _config_set checkexclude  ""             "default"
  _config_set include       ""             "default"
  _config_set exclude       ""             "default"
  _config_set labels        ""             "default"
}

config_load_file() {
  _clf_file=""
  if [ -n "${DBS_CONFIG_FILE:-}" ]; then
    if [ ! -f "$DBS_CONFIG_FILE" ]; then
      printf "Error: Config file not found: %s\n" "$DBS_CONFIG_FILE" >&2
      return 1
    fi
    _clf_file="$DBS_CONFIG_FILE"
  elif [ -f "./docker-bench-security.conf" ]; then
    _clf_file="./docker-bench-security.conf"
  elif [ -f "/etc/docker-bench-security.conf" ]; then
    _clf_file="/etc/docker-bench-security.conf"
  fi

  if [ -z "$_clf_file" ]; then
    return 0
  fi

  _clf_linenum=0
  while IFS= read -r _clf_line || [ -n "$_clf_line" ]; do
    _clf_linenum=$((_clf_linenum + 1))

    # Skip blank lines and comments
    case "$_clf_line" in
      ""|\#*) continue ;;
    esac
    # Also skip lines that are only whitespace or start with whitespace then #
    _clf_stripped=$(printf '%s' "$_clf_line" | sed 's/^[[:space:]]*//')
    case "$_clf_stripped" in
      ""|\#*) continue ;;
    esac

    # Parse key=value (split on first =)
    _clf_key=$(printf '%s' "$_clf_stripped" | sed 's/=.*//')
    _clf_val=$(printf '%s' "$_clf_stripped" | sed 's/[^=]*=//')

    # Trim whitespace from key and value
    _clf_key=$(printf '%s' "$_clf_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    _clf_val=$(printf '%s' "$_clf_val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Strip surrounding quotes from value
    case "$_clf_val" in
      \"*\") _clf_val=$(printf '%s' "$_clf_val" | sed 's/^"//;s/"$//') ;;
      \'*\') _clf_val=$(printf '%s' "$_clf_val" | sed 's/^'\''//;s/'\''$//') ;;
    esac

    # Validate key
    if ! _config_is_valid_key "$_clf_key"; then
      printf "Error: Unknown config key '%s' at %s:%d\n" "$_clf_key" "$_clf_file" "$_clf_linenum" >&2
      return 1
    fi

    # Map to shell variable
    _clf_var=$(_config_map_key_to_var "$_clf_key")

    # Normalize booleans
    if _config_is_bool_var "$_clf_var"; then
      _clf_norm=$(_config_normalize_bool "$_clf_val")
      if [ $? -ne 0 ]; then
        printf "Error: Invalid boolean value '%s' for key '%s' at %s:%d\n" \
          "$_clf_val" "$_clf_key" "$_clf_file" "$_clf_linenum" >&2
        return 1
      fi
      _clf_val=$(_config_convert_bool_for_var "$_clf_var" "$_clf_norm")
    fi

    _config_set "$_clf_var" "$_clf_val" "config:$_clf_file"
  done < "$_clf_file"

  return 0
}

config_load_env() {
  for _cle_key in $(_config_valid_keys); do
    _cle_env=$(_config_map_key_to_env "$_cle_key")
    _cle_var=$(_config_map_key_to_var "$_cle_key")

    # Check if env var is set (distinguishes unset from empty)
    eval "_cle_isset=\${${_cle_env}+x}"
    if [ -z "$_cle_isset" ]; then
      continue
    fi

    eval "_cle_val=\"\${${_cle_env}}\""

    # Normalize booleans
    if _config_is_bool_var "$_cle_var"; then
      _cle_norm=$(_config_normalize_bool "$_cle_val")
      if [ $? -ne 0 ]; then
        printf "Error: Invalid boolean value '%s' in environment variable %s\n" \
          "$_cle_val" "$_cle_env" >&2
        return 1
      fi
      _cle_val=$(_config_convert_bool_for_var "$_cle_var" "$_cle_norm")
    fi

    _config_set "$_cle_var" "$_cle_val" "env:$_cle_env"
  done
  return 0
}

config_set_from_cli() {
  _config_set "$1" "$2" "cli:$3"
}

config_validate() {
  _cv_errors=0

  # Validate limit is a non-negative integer
  case "$limit" in
    *[!0-9]*)
      printf "Error: Invalid limit '%s' (source: %s): must be a non-negative integer\n" \
        "$limit" "$limit_src" >&2
      _cv_errors=$((_cv_errors + 1))
      ;;
  esac

  # Validate log file parent directory exists
  _cv_logdir=$(dirname "$logger")
  if [ ! -d "$_cv_logdir" ]; then
    printf "Error: Log file directory '%s' does not exist (source: %s)\n" \
      "$_cv_logdir" "$logger_src" >&2
    _cv_errors=$((_cv_errors + 1))
  fi

  # Validate nocolor has expected internal value
  if [ -n "$nocolor" ] && [ "$nocolor" != "nocolor" ]; then
    printf "Error: Invalid no_color value '%s' (source: %s)\n" \
      "$nocolor" "$nocolor_src" >&2
    _cv_errors=$((_cv_errors + 1))
  fi

  # Validate printremediation has expected internal value
  if [ "$printremediation" != "0" ] && [ "$printremediation" != "1" ]; then
    printf "Error: Invalid print_remediation value '%s' (source: %s)\n" \
      "$printremediation" "$printremediation_src" >&2
    _cv_errors=$((_cv_errors + 1))
  fi

  if [ "$_cv_errors" -gt 0 ]; then
    return 1
  fi
  return 0
}

config_print_summary() {
  _cps_nocolor_display="false"
  if [ "$nocolor" = "nocolor" ]; then
    _cps_nocolor_display="true"
  fi
  _cps_remediation_display="false"
  if [ "$printremediation" = "1" ]; then
    _cps_remediation_display="true"
  fi

  logit ""
  logit "[CONFIG] Effective configuration:"
  logit "[CONFIG]   log_file          = ${logger} (source: ${logger_src})"
  logit "[CONFIG]   no_color          = ${_cps_nocolor_display} (source: ${nocolor_src})"
  logit "[CONFIG]   limit             = ${limit} (source: ${limit_src})"
  logit "[CONFIG]   print_remediation = ${_cps_remediation_display} (source: ${printremediation_src})"
  logit "[CONFIG]   trust_users       = ${dockertrustusers:-<empty>} (source: ${dockertrustusers_src})"
  logit "[CONFIG]   check             = ${check:-<empty>} (source: ${check_src})"
  logit "[CONFIG]   check_exclude     = ${checkexclude:-<empty>} (source: ${checkexclude_src})"
  logit "[CONFIG]   include           = ${include:-<empty>} (source: ${include_src})"
  logit "[CONFIG]   exclude           = ${exclude:-<empty>} (source: ${exclude_src})"
  logit "[CONFIG]   labels            = ${labels:-<empty>} (source: ${labels_src})"
  logit ""
}

config_get_source() {
  eval "printf '%s' \"\${${1}_src}\""
}
