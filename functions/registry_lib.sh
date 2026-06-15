#!/bin/sh
# ============================================================
# Check Registry — single source of truth for check grouping.
# All group membership is defined here as _REG_<name> variables.
# POSIX sh compatible (no bash arrays).
# ============================================================

# -----------------------------------------------------------
# Section A: Primary section groups (ordered check lists)
# -----------------------------------------------------------

_REG_host_configuration="\
check_1 check_1_1 \
check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
check_1_1_16 check_1_1_17 check_1_1_18 \
check_1_2 check_1_2_1 check_1_2_2 \
check_1_end"

_REG_docker_daemon_configuration="\
check_2 \
check_2_1 check_2_2 check_2_3 check_2_4 check_2_5 \
check_2_6 check_2_7 check_2_8 check_2_9 check_2_10 \
check_2_11 check_2_12 check_2_13 check_2_14 check_2_15 \
check_2_16 check_2_17 check_2_18 \
check_2_end"

_REG_docker_daemon_files="\
check_3 \
check_3_1 check_3_2 check_3_3 check_3_4 check_3_5 \
check_3_6 check_3_7 check_3_8 check_3_9 check_3_10 \
check_3_11 check_3_12 check_3_13 check_3_14 check_3_15 \
check_3_16 check_3_17 check_3_18 check_3_19 check_3_20 \
check_3_21 check_3_22 check_3_23 check_3_24 \
check_3_end"

_REG_container_images="\
check_4 \
check_4_1 check_4_2 check_4_3 check_4_4 check_4_5 \
check_4_6 check_4_7 check_4_8 check_4_9 check_4_10 \
check_4_11 check_4_12 \
check_4_end"

_REG_container_runtime="\
check_5 check_running_containers \
check_5_1 check_5_2 check_5_3 check_5_4 check_5_5 \
check_5_6 check_5_7 check_5_8 check_5_9 check_5_10 \
check_5_11 check_5_12 check_5_13 check_5_14 check_5_15 \
check_5_16 check_5_17 check_5_18 check_5_19 check_5_20 \
check_5_21 check_5_22 check_5_23 check_5_24 check_5_25 \
check_5_26 check_5_27 check_5_28 check_5_29 check_5_30 \
check_5_31 check_5_32 \
check_5_end"

_REG_docker_security_operations="\
check_6 check_6_1 check_6_2 check_6_end"

_REG_docker_swarm_configuration="\
check_7 \
check_7_1 check_7_2 check_7_3 check_7_4 check_7_5 \
check_7_6 check_7_7 check_7_8 check_7_9 \
check_7_end"

_REG_docker_enterprise_configuration="\
check_8 check_product_license \
check_8_1 check_8_1_1 check_8_1_2 check_8_1_3 check_8_1_4 \
check_8_1_5 check_8_1_6 check_8_1_7 \
check_8_2 check_8_2_1 \
check_8_end"

_REG_community_checks="\
check_c check_c_1 check_c_1_1 check_c_2 \
check_c_5_3_1 check_c_5_3_2 check_c_5_3_3 check_c_5_3_4 \
check_c_end"

# -----------------------------------------------------------
# Section A.2: Sub-groups
# -----------------------------------------------------------

_REG_linux_hosts_specific_configuration="\
check_1_1 \
check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
check_1_1_16 check_1_1_17 check_1_1_18"

_REG_host_general_configuration="\
check_1 check_1_2 check_1_2_1 check_1_2_2 check_1_end"

_REG_universal_control_plane_configuration="\
check_8 \
check_8_1 check_8_1_1 check_8_1_2 check_8_1_3 check_8_1_4 \
check_8_1_5 check_8_1_6 check_8_1_7 \
check_8_end"

_REG_docker_trusted_registry_configuration="\
check_8 check_8_2 check_8_2_1 check_8_end"

# -----------------------------------------------------------
# Section A.3: Level-1 variants
# -----------------------------------------------------------

_REG_host_configuration_level1="check_1 check_1_end"
_REG_docker_daemon_configuration_level1="check_2 check_2_end"
_REG_docker_daemon_files_level1="check_3 check_3_end"
_REG_container_images_level1="check_4 check_4_end"
_REG_container_runtime_level1="check_5 check_5_end"
_REG_docker_security_operations_level1="check_6 check_6_1 check_6_2 check_6_end"
_REG_docker_swarm_configuration_level1="check_7 check_7_end"
_REG_docker_enterprise_configuration_level1="\
check_8 check_product_license \
check_8_1 check_8_1_1 check_8_1_2 check_8_1_3 check_8_1_4 \
check_8_1_5 check_8_1_6 check_8_1_7 \
check_8_2 check_8_2_1 \
check_8_end"

# -----------------------------------------------------------
# Section A.4: CIS Controls v8 Implementation Groups
# -----------------------------------------------------------

_REG_cis_controls_v8_ig1="\
check_1_1_2 check_1_1_3 \
check_2_1 check_2_13 check_2_14 \
check_3_1 check_3_2 check_3_3 check_3_4 check_3_5 \
check_3_6 check_3_7 check_3_8 check_3_9 check_3_10 \
check_3_11 check_3_12 check_3_13 check_3_14 check_3_15 \
check_3_16 check_3_17 check_3_18 check_3_19 check_3_20 \
check_3_21 check_3_22 check_3_23 check_3_24 \
check_4_8 check_4_11 \
check_5_5 check_5_14 check_5_18 check_5_22 check_5_23 \
check_5_24 check_5_25 check_5_26 check_5_32 \
check_7_2 check_7_6 check_7_7 check_7_8"

_REG_cis_controls_v8_ig2="\
check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
check_1_1_16 check_1_1_17 check_1_1_18 \
check_1_2_1 check_1_2_2 \
check_2_1 check_2_2 check_2_3 check_2_4 check_2_5 \
check_2_7 check_2_8 check_2_11 check_2_13 check_2_14 \
check_2_15 check_2_16 check_2_18 \
check_3_1 check_3_2 check_3_3 check_3_4 check_3_5 \
check_3_6 check_3_7 check_3_8 check_3_9 check_3_10 \
check_3_11 check_3_12 check_3_13 check_3_14 check_3_15 \
check_3_16 check_3_17 check_3_18 check_3_19 check_3_20 \
check_3_21 check_3_22 check_3_23 check_3_24 \
check_4_2 check_4_3 check_4_4 check_4_7 check_4_8 check_4_9 check_4_11 \
check_5_1 check_5_2 check_5_3 check_5_4 check_5_5 \
check_5_7 check_5_10 check_5_11 check_5_12 check_5_14 \
check_5_16 check_5_17 check_5_18 check_5_19 check_5_21 \
check_5_22 check_5_23 check_5_24 check_5_25 check_5_26 \
check_5_27 check_5_30 check_5_31 check_5_32 \
check_6_1 check_6_2 \
check_7_2 check_7_3 check_7_5 check_7_6 check_7_7 check_7_8 check_7_9"

_REG_cis_controls_v8_ig3="\
check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
check_1_1_16 check_1_1_17 check_1_1_18 \
check_1_2_1 check_1_2_2 \
check_2_1 check_2_2 check_2_3 check_2_4 check_2_5 \
check_2_7 check_2_8 check_2_11 check_2_13 check_2_14 \
check_2_15 check_2_16 check_2_18 \
check_3_1 check_3_2 check_3_3 check_3_4 check_3_5 \
check_3_6 check_3_7 check_3_8 check_3_9 check_3_10 \
check_3_11 check_3_12 check_3_13 check_3_14 check_3_15 \
check_3_16 check_3_17 check_3_18 check_3_19 check_3_20 \
check_3_21 check_3_22 check_3_23 check_3_24 \
check_4_2 check_4_3 check_4_4 check_4_6 check_4_7 check_4_8 check_4_9 check_4_11 check_4_12 \
check_5_1 check_5_2 check_5_3 check_5_4 check_5_5 \
check_5_7 check_5_8 check_5_9 check_5_10 check_5_11 check_5_12 check_5_14 \
check_5_16 check_5_17 check_5_18 check_5_19 check_5_21 \
check_5_22 check_5_23 check_5_24 check_5_25 check_5_26 \
check_5_27 check_5_30 check_5_31 check_5_32 \
check_6_1 check_6_2 \
check_7_2 check_7_3 check_7_5 check_7_6 check_7_7 check_7_8 check_7_9"

# -----------------------------------------------------------
# Section A.5: Composite / meta groups
# -----------------------------------------------------------

_REG_cis="\
host_configuration docker_daemon_configuration docker_daemon_files \
container_images container_runtime docker_security_operations \
docker_swarm_configuration"

_REG_cis_level1="\
host_configuration_level1 docker_daemon_configuration_level1 \
docker_daemon_files_level1 container_images_level1 \
container_runtime_level1 docker_security_operations_level1 \
docker_swarm_configuration_level1"

_REG_community="community_checks"

_REG_all="cis docker_enterprise_configuration community"

# -----------------------------------------------------------
# Master list of all registered group names
# -----------------------------------------------------------

_ALL_GROUPS="\
host_configuration docker_daemon_configuration docker_daemon_files \
container_images container_runtime docker_security_operations \
docker_swarm_configuration docker_enterprise_configuration community_checks \
linux_hosts_specific_configuration host_general_configuration \
universal_control_plane_configuration docker_trusted_registry_configuration \
host_configuration_level1 docker_daemon_configuration_level1 \
docker_daemon_files_level1 container_images_level1 \
container_runtime_level1 docker_security_operations_level1 \
docker_swarm_configuration_level1 docker_enterprise_configuration_level1 \
cis_controls_v8_ig1 cis_controls_v8_ig2 cis_controls_v8_ig3 \
cis cis_level1 community all"

# ============================================================
# Section B: Lookup and iteration functions
# ============================================================

# Validate that a name contains only safe characters [a-zA-Z0-9_].
_validate_name() {
  case "$1" in
    *[!a-zA-Z0-9_]*) printf 'Invalid name: %s\n' "$1" >&2; return 1 ;;
    '') printf 'Empty name\n' >&2; return 1 ;;
  esac
}

# Get the ordered member list for a registered group.
# Returns empty string (and false) if the name is not a registered group.
get_group_members() {
  _validate_name "$1" || return 1
  eval "printf '%s' \"\$_REG_$1\""
}

# Test whether a name is a registered group.
is_group() {
  _validate_name "$1" || return 1
  eval "[ -n \"\$_REG_$1\" ]"
}

# Recursively expand a group into its leaf check function names.
# Output: one function name per line (space-separated on each line from sub-groups).
expand_group() {
  _validate_name "$1" || return 1
  local _members
  _members=$(get_group_members "$1")
  if [ -z "$_members" ]; then
    return 1
  fi
  for _m in $_members; do
    if is_group "$_m"; then
      expand_group "$_m"
    else
      printf '%s\n' "$_m"
    fi
  done
}

# Run all checks in a group, in order (recursing into sub-groups).
run_group() {
  _validate_name "$1" || return 1
  local _members
  _members=$(get_group_members "$1")
  if [ -z "$_members" ]; then
    printf 'Unknown group: %s\n' "$1" >&2
    return 1
  fi
  for _m in $_members; do
    if is_group "$_m"; then
      run_group "$_m"
    else
      "$_m"
    fi
  done
}

# ============================================================
# Section C: Generate backward-compatible wrapper functions
# ============================================================

_generate_group_functions() {
  for _g in $_ALL_GROUPS; do
    eval "${_g}() { run_group ${_g}; }"
  done
}
_generate_group_functions
