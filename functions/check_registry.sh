#!/bin/sh
# --------------------------------------------------------------------------------------------
# Check Registry — docker-bench-security
#
# Provides a shell-readable registration and grouping mechanism for benchmark checks.
# POSIX-sh compatible (no bash arrays or associative arrays).
#
# Data model:
#   _REG_ALL_CHECKS   space-separated list of all registered leaf check function names
#   _REG_ALL_GROUPS   space-separated list of all registered group names
#   _REG_GRP_<name>   per-group space-separated member list (checks or sub-group names)
# --------------------------------------------------------------------------------------------

_REG_ALL_CHECKS=""
_REG_ALL_GROUPS=""

# _reg_contains ITEM LIST — returns 0 if ITEM is in space-separated LIST
_reg_contains() {
  _rc_item="$1"; shift
  for _rc_i in $*; do
    [ "$_rc_i" = "$_rc_item" ] && return 0
  done
  return 1
}

# register_check FUNC_NAME — add a leaf check to the global registry
register_check() {
  if ! _reg_contains "$1" $_REG_ALL_CHECKS; then
    _REG_ALL_CHECKS="${_REG_ALL_CHECKS} $1"
  fi
}

# register_group GROUP_NAME MEMBER1 MEMBER2 ... — register a named group
# Members are leaf check function names or sub-group names (NOT headers/footers).
register_group() {
  _rg_name="$1"; shift
  if ! _reg_contains "$_rg_name" $_REG_ALL_GROUPS; then
    _REG_ALL_GROUPS="${_REG_ALL_GROUPS} $_rg_name"
  fi
  eval "_REG_GRP_${_rg_name}=\"$*\""
}

# _is_registered_group NAME — returns 0 if NAME is a registered group
_is_registered_group() {
  _reg_contains "$1" $_REG_ALL_GROUPS
}

# _expand_group NAME [VISITED] — recursively expand group to leaf check names only
_expand_group() {
  _eg_name="$1"
  _eg_visited="${2:-}"
  _eg_result=""

  if _reg_contains "$_eg_name" $_eg_visited; then
    return
  fi
  _eg_visited="$_eg_visited $_eg_name"

  if _is_registered_group "$_eg_name"; then
    eval "_eg_members=\"\$_REG_GRP_${_eg_name}\""
    for _eg_m in $_eg_members; do
      if _is_registered_group "$_eg_m"; then
        _eg_sub="$(_expand_group "$_eg_m" "$_eg_visited")"
        _eg_visited="$_eg_visited $_eg_sub"
        for _eg_s in $_eg_sub; do
          if ! _reg_contains "$_eg_s" $_eg_result; then
            _eg_result="${_eg_result} $_eg_s"
          fi
        done
      else
        if ! _reg_contains "$_eg_m" $_eg_result; then
          _eg_result="${_eg_result} $_eg_m"
        fi
      fi
    done
  else
    _eg_result="$_eg_name"
  fi

  printf "%s" "$_eg_result"
}

# _is_excluded NAME EXCLUDE_CSV — returns 0 if NAME matches any exclusion (anchored)
_is_excluded() {
  _ie_name="$1"
  _ie_excl="$2"
  [ -z "$_ie_excl" ] && return 1

  _ie_saved_IFS="$IFS"
  IFS=','
  for _ie_e in $_ie_excl; do
    IFS="$_ie_saved_IFS"
    [ -z "$_ie_e" ] && continue
    if [ "$_ie_name" = "$_ie_e" ]; then
      return 0
    fi
  done
  IFS="$_ie_saved_IFS"
  return 1
}

# _is_leaf_check NAME — returns 0 if NAME is a leaf check (not a section header/footer)
# Headers: check_1, check_1_1, check_c, check_c_5  (<=2 suffix components)
# Leaves:  check_1_1_1, check_c_1_1, check_5_32     (>=3 suffix components)
# Footers: check_*_end
_is_leaf_check() {
  case "$1" in
    *_end) return 1 ;;
  esac

  _ilc_suffix="${1#check_}"
  _ilc_count=0
  _ilc_rest="$_ilc_suffix"
  while [ -n "$_ilc_rest" ]; do
    _ilc_count=$((_ilc_count + 1))
    case "$_ilc_rest" in
      *_*) _ilc_rest="${_ilc_rest#*_}" ;;
      *) break ;;
    esac
  done

  [ "$_ilc_count" -ge 3 ]
}

# _run_group GROUP_NAME EXCLUDE_CSV — run all checks in a group
# For meta-groups (all members are sub-groups): delegates to sub-groups with exclusion.
# For section groups: calls function for no-exclude, or iterates with exclusion filtering.
# Section headers/footers are always emitted; only leaf checks are subject to exclusion.
_run_group() {
  _rg_group="$1"
  _rg_excl="$2"

  if ! _is_registered_group "$_rg_group"; then
    return 1
  fi

  if [ -z "$_rg_excl" ]; then
    # No exclusion — call the function directly (backward-compatible)
    "$_rg_group"
    return $?
  fi

  # Check if this is a meta-group (all registered members are sub-groups)
  eval "_rg_members=\"\$_REG_GRP_${_rg_group}\""
  _rg_all_groups=true
  for _rg_m in $_rg_members; do
    if ! _is_registered_group "$_rg_m"; then
      _rg_all_groups=false
      break
    fi
  done

  if $_rg_all_groups; then
    # Meta-group: delegate to each sub-group with exclusion
    for _rg_m in $_rg_members; do
      _run_group "$_rg_m" "$_rg_excl"
    done
    return
  fi

  # Section group with excludes:
  # 1. Determine section header/footer from the first member's prefix
  _rg_first=""
  for _rg_m in $_rg_members; do
    _rg_first="$_rg_m"
    break
  done

  # Extract section number (e.g., check_1_1_1 -> 1, check_c_1_1 -> c)
  _rg_sec="${_rg_first#check_}"
  _rg_sec="${_rg_sec%%_*}"

  # Emit section header
  if command -v "check_${_rg_sec}" >/dev/null 2>&1; then
    "check_${_rg_sec}"
  fi

  # Call pre-hook if defined (e.g., check_running_containers, check_product_license)
  if command -v "_pre_hook_${_rg_group}" >/dev/null 2>&1; then
    "_pre_hook_${_rg_group}"
  fi

  # Iterate expanded leaf checks in order, filter excluded
  _rg_checks="$(_expand_group "$_rg_group")"
  _rg_prev_sub=""
  for _rg_c in $_rg_checks; do
    # Emit sub-section header if it changed
    _rg_sub="${_rg_c#check_}"
    _rg_sub="${_rg_sub%_*}"
    if [ "$_rg_sub" != "$_rg_prev_sub" ] && [ "$_rg_sub" != "$_rg_c" ]; then
      # Derive the sub-header function name
      _rg_hdr="check_${_rg_sub}"
      if command -v "$_rg_hdr" >/dev/null 2>&1; then
        "$_rg_hdr"
      fi
      _rg_prev_sub="$_rg_sub"
    fi

    if ! _is_excluded "$_rg_c" "$_rg_excl"; then
      "$_rg_c"
    fi
  done

  # Emit section footer
  if command -v "check_${_rg_sec}_end" >/dev/null 2>&1; then
    "check_${_rg_sec}_end"
  fi
}

# _list_all_checks — print all registered groups and their leaf checks
_list_all_checks() {
  for _lac_g in $_REG_ALL_GROUPS; do
    eval "_lac_members=\"\$_REG_GRP_${_lac_g}\""
    _lac_has_leaves=false
    for _lac_m in $_lac_members; do
      if ! _is_registered_group "$_lac_m"; then
        _lac_has_leaves=true
        break
      fi
    done
    if $_lac_has_leaves; then
      printf "%s\n" "$_lac_g:"
      for _lac_m in $_lac_members; do
        if ! _is_registered_group "$_lac_m"; then
          printf "  %s\n" "$_lac_m"
        fi
      done
    else
      printf "%s (meta-group)\n" "$_lac_g"
      for _lac_m in $_lac_members; do
        printf "  -> %s\n" "$_lac_m"
      done
    fi
  done
}

# get_all_checks — return space-separated list of all registered leaf check names
get_all_checks() {
  printf "%s" "$_REG_ALL_CHECKS"
}

# get_all_groups — return space-separated list of all registered group names
get_all_groups() {
  printf "%s" "$_REG_ALL_GROUPS"
}
