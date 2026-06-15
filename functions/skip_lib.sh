#!/bin/bash
# --------------------------------------------------------------------------------------------
# skip_lib.sh - Centralized skip/exclude rule parser for Docker Bench for Security
#
# Merges skip rules from three sources (config file, CLI -e, environment),
# validates them against the known check registry, normalizes dot-notation
# IDs (e.g. "2.2" -> "check_2_2"), and reports:
#   - unknown check IDs   (hard error)
#   - duplicate entries    (warning, auto-deduplicated)
#   - empty / blank rules  (warning, silently dropped)
#
# Public API:
#   parse_skip_rules <config_file> <cli_exclude>
#     Sets SKIP_EXCLUDE_LIST (space-separated validated function names)
#     Returns 0 on success, 1 if any hard error was found.
# --------------------------------------------------------------------------------------------

SKIP_ERRORS=0       # number of hard errors encountered
SKIP_WARNINGS=0     # number of warnings encountered
SKIP_EXCLUDE_LIST="" # final validated, deduplicated list
SKIP_REGEX=""       # grep -E pattern built from SKIP_EXCLUDE_LIST

# Internal accumulator (avoids subshell variable-loss)
_skip_result=""

# --------------------------------------------------------------------------------------------
# _build_check_registry
#   Populate KNOWN_CHECKS with every valid callable name:
#     - all check_* functions defined in tests/*.sh
#     - all group/section functions defined in functions_lib.sh
# --------------------------------------------------------------------------------------------
_build_check_registry() {
  KNOWN_CHECKS=""

  # Individual check functions from tests/*.sh
  if [ -d "$LIBEXEC/tests" ]; then
    for tf in "$LIBEXEC"/tests/*.sh; do
      [ -f "$tf" ] || continue
      while IFS= read -r _line; do
        # Strip everything from first '(' onward, then trim whitespace
        _candidate="${_line%%(*}"
        # Trim leading/trailing whitespace
        _candidate=$(printf '%s' "$_candidate" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Only accept lines that originally contained '()' and start with check_
        case "$_line" in
          *"()"*)
            case "$_candidate" in
              check_*) KNOWN_CHECKS="$KNOWN_CHECKS $_candidate" ;;
            esac
            ;;
        esac
      done < "$tf"
    done
  fi

  # Group / section functions from functions_lib.sh
  if [ -f "$LIBEXEC/functions/functions_lib.sh" ]; then
    while IFS= read -r _line; do
      case "$_line" in
        *"()"*)
          _candidate="${_line%%(*}"
          _candidate=$(printf '%s' "$_candidate" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          case "$_candidate" in
            check_*|"") ;;
            *) KNOWN_CHECKS="$KNOWN_CHECKS $_candidate" ;;
          esac
          ;;
      esac
    done < "$LIBEXEC/functions/functions_lib.sh"
  fi
}

# --------------------------------------------------------------------------------------------
# _is_known_check <name>
#   Returns 0 if <name> is in KNOWN_CHECKS, 1 otherwise.
# --------------------------------------------------------------------------------------------
_is_known_check() {
  local _target="$1"
  local _item
  for _item in $KNOWN_CHECKS; do
    if [ "$_item" = "$_target" ]; then
      return 0
    fi
  done
  return 1
}

# --------------------------------------------------------------------------------------------
# _normalize_id <raw_id>
#   Convert a dot-notation check ID to function-name form:
#     "2.2"       -> "check_2_2"
#     "C.5.3.1"   -> "check_c_5_3_1"
#     "check_2_2" -> "check_2_2"  (unchanged)
#   Prints the normalized name to stdout.
# --------------------------------------------------------------------------------------------
_normalize_id() {
  local _raw="$1"
  case "$_raw" in
    check_*|host_configuration*|docker_*|container_*|community*|cis*|all|universal_*|linux_*|running_containers|product_license)
      printf '%s\n' "$_raw"
      ;;
    *)
      local _normalized
      _normalized=$(printf '%s' "$_raw" | tr '[:upper:]' '[:lower:]' | tr '.' '_')
      printf 'check_%s\n' "$_normalized"
      ;;
  esac
}

# --------------------------------------------------------------------------------------------
# _is_duplicate <name> <list>
#   Returns 0 if <name> already appears in space-separated <list>.
# --------------------------------------------------------------------------------------------
_is_duplicate() {
  local _target="$1"
  local _list="$2"
  local _item
  for _item in $_list; do
    if [ "$_item" = "$_target" ]; then
      return 0
    fi
  done
  return 1
}

# --------------------------------------------------------------------------------------------
# _add_skip <raw_id> <source>
#   Normalize, validate, and append a single rule to _skip_result.
#   Mutates _skip_result, SKIP_ERRORS, SKIP_WARNINGS directly (no subshell).
#   Prints warnings/errors to stderr.
# --------------------------------------------------------------------------------------------
_add_skip() {
  local _raw="$1"
  local _source="$2"

  # --- Empty / blank check ---
  if [ -z "$_raw" ]; then
    echo "WARNING: empty skip rule ignored (source: $_source)" >&2
    SKIP_WARNINGS=$((SKIP_WARNINGS + 1))
    return
  fi

  # Strip leading/trailing whitespace
  _raw=$(printf '%s' "$_raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$_raw" ]; then
    echo "WARNING: blank skip rule ignored (source: $_source)" >&2
    SKIP_WARNINGS=$((SKIP_WARNINGS + 1))
    return
  fi

  # --- Normalize ---
  local _normalized
  _normalized=$(_normalize_id "$_raw")

  # --- Unknown check ---
  if ! _is_known_check "$_normalized"; then
    echo "ERROR: unknown check ID '$_raw' (normalized: '$_normalized') from $_source" >&2
    SKIP_ERRORS=$((SKIP_ERRORS + 1))
    return
  fi

  # --- Duplicate ---
  if _is_duplicate "$_normalized" "$_skip_result"; then
    echo "WARNING: duplicate skip rule '$_raw' (normalized: '$_normalized') from $_source -- ignored" >&2
    SKIP_WARNINGS=$((SKIP_WARNINGS + 1))
    return
  fi

  # --- Append ---
  if [ -z "$_skip_result" ]; then
    _skip_result="$_normalized"
  else
    _skip_result="$_skip_result $_normalized"
  fi
}

# --------------------------------------------------------------------------------------------
# parse_skip_rules <config_file> <cli_exclude>
#
#   config_file : path to skip config file ("" to skip file parsing)
#   cli_exclude : raw -e argument value  ("" if not provided)
#
#   Sets SKIP_EXCLUDE_LIST, SKIP_ERRORS, SKIP_WARNINGS.
#   Returns 0 if no hard errors, 1 otherwise.
# --------------------------------------------------------------------------------------------
parse_skip_rules() {
  local _config_file="${1:-}"
  local _cli_exclude="${2:-}"

  SKIP_EXCLUDE_LIST=""
  SKIP_ERRORS=0
  SKIP_WARNINGS=0
  _skip_result=""

  # Build registry
  _build_check_registry

  # ---- Source 1: config file ----
  if [ -n "$_config_file" ] && [ -f "$_config_file" ]; then
    local _lineno=0
    local _line
    while IFS= read -r _line || [ -n "$_line" ]; do
      _lineno=$((_lineno + 1))
      # Strip inline comments
      _line="${_line%%#*}"
      # Strip leading/trailing whitespace
      _line=$(printf '%s' "$_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      # Skip blank lines
      [ -z "$_line" ] && continue

      _add_skip "$_line" "config:$_config_file:$_lineno"
    done < "$_config_file"
  fi

  # ---- Source 2: CLI -e argument ----
  if [ -n "$_cli_exclude" ]; then
    local _saved_ifs="$IFS"
    IFS=','
    for _item in $_cli_exclude; do
      IFS="$_saved_ifs"
      _add_skip "$_item" "CLI -e"
    done
    IFS="$_saved_ifs"
  fi

  # ---- Source 3: environment variable DBS_SKIP ----
  if [ -n "${DBS_SKIP:-}" ]; then
    local _saved_ifs="$IFS"
    IFS=','
    for _item in $DBS_SKIP; do
      IFS="$_saved_ifs"
      _add_skip "$_item" "env DBS_SKIP"
    done
    IFS="$_saved_ifs"
  fi

  SKIP_EXCLUDE_LIST="$_skip_result"

  if [ "$SKIP_ERRORS" -gt 0 ]; then
    return 1
  fi
  return 0
}

# --------------------------------------------------------------------------------------------
# build_skip_regex
#   Build a grep -E pattern from SKIP_EXCLUDE_LIST for use in the main loop.
#   Sets SKIP_REGEX.
# --------------------------------------------------------------------------------------------
build_skip_regex() {
  if [ -z "$SKIP_EXCLUDE_LIST" ]; then
    SKIP_REGEX=""
    return
  fi

  SKIP_REGEX=""
  local _item
  for _item in $SKIP_EXCLUDE_LIST; do
    if [ -z "$SKIP_REGEX" ]; then
      SKIP_REGEX="^${_item}$"
    else
      SKIP_REGEX="${SKIP_REGEX}|^${_item}$"
    fi
  done
}
