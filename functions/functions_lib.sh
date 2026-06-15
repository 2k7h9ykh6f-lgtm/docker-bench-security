#!/bin/sh
# --------------------------------------------------------------------------------------------
# Functions library — docker-bench-security
#
# This file defines:
#   1. Check and group registrations (via check_registry.sh)
#   2. Group functions (backward-compatible entry points)
#
# To add a new check:
#   1. Implement check_N_N_N() in the appropriate tests/*.sh file
#   2. Add: register_check check_N_N_N
#   3. Add check_N_N_N to the appropriate register_group call below
# --------------------------------------------------------------------------------------------

# Load the registry primitives
# shellcheck source=functions/check_registry.sh
. "${LIBEXEC:-.}/functions/check_registry.sh"

# --------------------------------------------------------------------------------------------
# 1. Register all leaf check functions
# --------------------------------------------------------------------------------------------

# Section 1 — Host Configuration
register_check check_1_1_1
register_check check_1_1_2
register_check check_1_1_3
register_check check_1_1_4
register_check check_1_1_5
register_check check_1_1_6
register_check check_1_1_7
register_check check_1_1_8
register_check check_1_1_9
register_check check_1_1_10
register_check check_1_1_11
register_check check_1_1_12
register_check check_1_1_13
register_check check_1_1_14
register_check check_1_1_15
register_check check_1_1_16
register_check check_1_1_17
register_check check_1_1_18
register_check check_1_2_1
register_check check_1_2_2

# Section 2 — Docker Daemon Configuration
register_check check_2_1
register_check check_2_2
register_check check_2_3
register_check check_2_4
register_check check_2_5
register_check check_2_6
register_check check_2_7
register_check check_2_8
register_check check_2_9
register_check check_2_10
register_check check_2_11
register_check check_2_12
register_check check_2_13
register_check check_2_14
register_check check_2_15
register_check check_2_16
register_check check_2_17
register_check check_2_18

# Section 3 — Docker Daemon Configuration Files
register_check check_3_1
register_check check_3_2
register_check check_3_3
register_check check_3_4
register_check check_3_5
register_check check_3_6
register_check check_3_7
register_check check_3_8
register_check check_3_9
register_check check_3_10
register_check check_3_11
register_check check_3_12
register_check check_3_13
register_check check_3_14
register_check check_3_15
register_check check_3_16
register_check check_3_17
register_check check_3_18
register_check check_3_19
register_check check_3_20
register_check check_3_21
register_check check_3_22
register_check check_3_23
register_check check_3_24

# Section 4 — Container Images
register_check check_4_1
register_check check_4_2
register_check check_4_3
register_check check_4_4
register_check check_4_5
register_check check_4_6
register_check check_4_7
register_check check_4_8
register_check check_4_9
register_check check_4_10
register_check check_4_11
register_check check_4_12

# Section 5 — Container Runtime
register_check check_5_1
register_check check_5_2
register_check check_5_3
register_check check_5_4
register_check check_5_5
register_check check_5_6
register_check check_5_7
register_check check_5_8
register_check check_5_9
register_check check_5_10
register_check check_5_11
register_check check_5_12
register_check check_5_13
register_check check_5_14
register_check check_5_15
register_check check_5_16
register_check check_5_17
register_check check_5_18
register_check check_5_19
register_check check_5_20
register_check check_5_21
register_check check_5_22
register_check check_5_23
register_check check_5_24
register_check check_5_25
register_check check_5_26
register_check check_5_27
register_check check_5_28
register_check check_5_29
register_check check_5_30
register_check check_5_31
register_check check_5_32

# Section 6 — Docker Security Operations
register_check check_6_1
register_check check_6_2

# Section 7 — Docker Swarm Configuration
register_check check_7_1
register_check check_7_2
register_check check_7_3
register_check check_7_4
register_check check_7_5
register_check check_7_6
register_check check_7_7
register_check check_7_8
register_check check_7_9

# Section 8 — Docker Enterprise Configuration
register_check check_8_1_1
register_check check_8_1_2
register_check check_8_1_3
register_check check_8_1_4
register_check check_8_1_5
register_check check_8_1_6
register_check check_8_1_7
register_check check_8_2_1

# Community Checks
register_check check_c_1_1
register_check check_c_5_3_1
register_check check_c_5_3_2
register_check check_c_5_3_3
register_check check_c_5_3_4

# --------------------------------------------------------------------------------------------
# 2. Register groups
#    Members are LEAF checks or sub-group names. Headers/footers are NOT listed here.
# --------------------------------------------------------------------------------------------

# Section groups
register_group host_configuration \
  check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
  check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
  check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
  check_1_1_16 check_1_1_17 check_1_1_18 \
  check_1_2_1 check_1_2_2

register_group linux_hosts_specific_configuration \
  check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
  check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
  check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
  check_1_1_16 check_1_1_17 check_1_1_18

register_group host_general_configuration \
  check_1_2_1 check_1_2_2

register_group docker_daemon_configuration \
  check_2_1 check_2_2 check_2_3 check_2_4 check_2_5 \
  check_2_6 check_2_7 check_2_8 check_2_9 check_2_10 \
  check_2_11 check_2_12 check_2_13 check_2_14 check_2_15 \
  check_2_16 check_2_17 check_2_18

register_group docker_daemon_files \
  check_3_1 check_3_2 check_3_3 check_3_4 check_3_5 \
  check_3_6 check_3_7 check_3_8 check_3_9 check_3_10 \
  check_3_11 check_3_12 check_3_13 check_3_14 check_3_15 \
  check_3_16 check_3_17 check_3_18 check_3_19 check_3_20 \
  check_3_21 check_3_22 check_3_23 check_3_24

register_group container_images \
  check_4_1 check_4_2 check_4_3 check_4_4 check_4_5 \
  check_4_6 check_4_7 check_4_8 check_4_9 check_4_10 \
  check_4_11 check_4_12

register_group container_runtime \
  check_5_1 check_5_2 check_5_3 check_5_4 check_5_5 \
  check_5_6 check_5_7 check_5_8 check_5_9 check_5_10 \
  check_5_11 check_5_12 check_5_13 check_5_14 check_5_15 \
  check_5_16 check_5_17 check_5_18 check_5_19 check_5_20 \
  check_5_21 check_5_22 check_5_23 check_5_24 check_5_25 \
  check_5_26 check_5_27 check_5_28 check_5_29 check_5_30 \
  check_5_31 check_5_32

register_group docker_security_operations \
  check_6_1 check_6_2

register_group docker_swarm_configuration \
  check_7_1 check_7_2 check_7_3 check_7_4 check_7_5 \
  check_7_6 check_7_7 check_7_8 check_7_9

register_group docker_enterprise_configuration \
  check_8_1_1 check_8_1_2 check_8_1_3 check_8_1_4 check_8_1_5 \
  check_8_1_6 check_8_1_7 check_8_2_1

register_group universal_control_plane_configuration \
  check_8_1_1 check_8_1_2 check_8_1_3 check_8_1_4 check_8_1_5 \
  check_8_1_6 check_8_1_7

register_group docker_trusted_registry_configuration \
  check_8_2_1

register_group community_checks \
  check_c_1_1 check_c_5_3_1 check_c_5_3_2 check_c_5_3_3 check_c_5_3_4

# Meta-groups (members are sub-group names)
register_group cis \
  host_configuration docker_daemon_configuration docker_daemon_files \
  container_images container_runtime docker_security_operations \
  docker_swarm_configuration

register_group community \
  community_checks

register_group all \
  cis docker_enterprise_configuration community

# CIS Controls v8 Implementation Groups
register_group cis_controls_v8_ig1 \
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
  check_7_2 check_7_6 check_7_7 check_7_8

register_group cis_controls_v8_ig2 \
  check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
  check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
  check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
  check_1_1_16 check_1_1_17 check_1_1_18 check_1_2_1 check_1_2_2 \
  check_2_1 check_2_2 check_2_3 check_2_4 check_2_5 \
  check_2_7 check_2_8 check_2_11 check_2_13 check_2_14 \
  check_2_15 check_2_16 check_2_18 \
  check_3_1 check_3_2 check_3_3 check_3_4 check_3_5 \
  check_3_6 check_3_7 check_3_8 check_3_9 check_3_10 \
  check_3_11 check_3_12 check_3_13 check_3_14 check_3_15 \
  check_3_16 check_3_17 check_3_18 check_3_19 check_3_20 \
  check_3_21 check_3_22 check_3_23 check_3_24 \
  check_4_2 check_4_3 check_4_4 check_4_7 check_4_8 \
  check_4_9 check_4_11 \
  check_5_1 check_5_2 check_5_3 check_5_4 check_5_5 \
  check_5_7 check_5_10 check_5_11 check_5_12 check_5_14 \
  check_5_16 check_5_17 check_5_18 check_5_19 check_5_21 \
  check_5_22 check_5_23 check_5_24 check_5_25 check_5_26 \
  check_5_27 check_5_30 check_5_31 check_5_32 \
  check_6_1 check_6_2 \
  check_7_2 check_7_3 check_7_5 check_7_6 check_7_7 \
  check_7_8 check_7_9

register_group cis_controls_v8_ig3 \
  check_1_1_1 check_1_1_2 check_1_1_3 check_1_1_4 check_1_1_5 \
  check_1_1_6 check_1_1_7 check_1_1_8 check_1_1_9 check_1_1_10 \
  check_1_1_11 check_1_1_12 check_1_1_13 check_1_1_14 check_1_1_15 \
  check_1_1_16 check_1_1_17 check_1_1_18 check_1_2_1 check_1_2_2 \
  check_2_1 check_2_2 check_2_3 check_2_4 check_2_5 \
  check_2_7 check_2_8 check_2_11 check_2_13 check_2_14 \
  check_2_15 check_2_16 check_2_18 \
  check_3_1 check_3_2 check_3_3 check_3_4 check_3_5 \
  check_3_6 check_3_7 check_3_8 check_3_9 check_3_10 \
  check_3_11 check_3_12 check_3_13 check_3_14 check_3_15 \
  check_3_16 check_3_17 check_3_18 check_3_19 check_3_20 \
  check_3_21 check_3_22 check_3_23 check_3_24 \
  check_4_2 check_4_3 check_4_4 check_4_6 check_4_7 \
  check_4_8 check_4_9 check_4_11 check_4_12 \
  check_5_1 check_5_2 check_5_3 check_5_4 check_5_5 \
  check_5_7 check_5_8 check_5_9 check_5_10 check_5_11 \
  check_5_12 check_5_14 check_5_16 check_5_17 check_5_18 \
  check_5_19 check_5_21 check_5_22 check_5_23 check_5_24 \
  check_5_25 check_5_26 check_5_27 check_5_30 check_5_31 \
  check_5_32 \
  check_6_1 check_6_2 \
  check_7_2 check_7_3 check_7_5 check_7_6 check_7_7 \
  check_7_8 check_7_9

# --------------------------------------------------------------------------------------------
# 3. Pre-hooks for groups that need setup before running checks
#     Called by _run_group before iterating leaf checks.
# --------------------------------------------------------------------------------------------

_pre_hook_container_runtime() {
  check_running_containers
}

_pre_hook_docker_enterprise_configuration() {
  check_product_license
}

# --------------------------------------------------------------------------------------------
# 4. Group functions (backward-compatible entry points)
#    Each function delegates to _run_group which handles excludes via the registry.
#    When called without excludes, _run_group calls this function directly.
# --------------------------------------------------------------------------------------------

host_configuration() {
  check_1
  check_1_1
  check_1_1_1; check_1_1_2; check_1_1_3; check_1_1_4; check_1_1_5
  check_1_1_6; check_1_1_7; check_1_1_8; check_1_1_9; check_1_1_10
  check_1_1_11; check_1_1_12; check_1_1_13; check_1_1_14; check_1_1_15
  check_1_1_16; check_1_1_17; check_1_1_18
  check_1_2
  check_1_2_1; check_1_2_2
  check_1_end
}

host_configuration_level1() {
  check_1
  check_1_end
}

linux_hosts_specific_configuration() {
  check_1_1
  check_1_1_1; check_1_1_2; check_1_1_3; check_1_1_4; check_1_1_5
  check_1_1_6; check_1_1_7; check_1_1_8; check_1_1_9; check_1_1_10
  check_1_1_11; check_1_1_12; check_1_1_13; check_1_1_14; check_1_1_15
  check_1_1_16; check_1_1_17; check_1_1_18
}

host_general_configuration() {
  check_1
  check_1_2
  check_1_2_1; check_1_2_2
  check_1_end
}

docker_daemon_configuration() {
  check_2
  check_2_1; check_2_2; check_2_3; check_2_4; check_2_5
  check_2_6; check_2_7; check_2_8; check_2_9; check_2_10
  check_2_11; check_2_12; check_2_13; check_2_14; check_2_15
  check_2_16; check_2_17; check_2_18
  check_2_end
}

docker_daemon_configuration_level1() {
  check_2
  check_2_end
}

docker_daemon_files() {
  check_3
  check_3_1; check_3_2; check_3_3; check_3_4; check_3_5
  check_3_6; check_3_7; check_3_8; check_3_9; check_3_10
  check_3_11; check_3_12; check_3_13; check_3_14; check_3_15
  check_3_16; check_3_17; check_3_18; check_3_19; check_3_20
  check_3_21; check_3_22; check_3_23; check_3_24
  check_3_end
}

docker_daemon_files_level1() {
  check_3
  check_3_end
}

container_images() {
  check_4
  check_4_1; check_4_2; check_4_3; check_4_4; check_4_5
  check_4_6; check_4_7; check_4_8; check_4_9; check_4_10
  check_4_11; check_4_12
  check_4_end
}

container_images_level1() {
  check_4
  check_4_end
}

container_runtime() {
  check_5
  check_running_containers
  check_5_1; check_5_2; check_5_3; check_5_4; check_5_5
  check_5_6; check_5_7; check_5_8; check_5_9; check_5_10
  check_5_11; check_5_12; check_5_13; check_5_14; check_5_15
  check_5_16; check_5_17; check_5_18; check_5_19; check_5_20
  check_5_21; check_5_22; check_5_23; check_5_24; check_5_25
  check_5_26; check_5_27; check_5_28; check_5_29; check_5_30
  check_5_31; check_5_32
  check_5_end
}

container_runtime_level1() {
  check_5
  check_5_end
}

docker_security_operations() {
  check_6
  check_6_1; check_6_2
  check_6_end
}

docker_security_operations_level1() {
  check_6
  check_6_1; check_6_2
  check_6_end
}

docker_swarm_configuration() {
  check_7
  check_7_1; check_7_2; check_7_3; check_7_4; check_7_5
  check_7_6; check_7_7; check_7_8; check_7_9
  check_7_end
}

docker_swarm_configuration_level1() {
  check_7
  check_7_end
}

docker_enterprise_configuration() {
  check_8
  check_product_license
  check_8_1
  check_8_1_1; check_8_1_2; check_8_1_3; check_8_1_4; check_8_1_5
  check_8_1_6; check_8_1_7
  check_8_2
  check_8_2_1
  check_8_end
}

docker_enterprise_configuration_level1() {
  check_8
  check_product_license
  check_8_1
  check_8_1_1; check_8_1_2; check_8_1_3; check_8_1_4; check_8_1_5
  check_8_1_6; check_8_1_7
  check_8_2
  check_8_2_1
  check_8_end
}

universal_control_plane_configuration() {
  check_8
  check_8_1
  check_8_1_1; check_8_1_2; check_8_1_3; check_8_1_4; check_8_1_5
  check_8_1_6; check_8_1_7
  check_8_end
}

docker_trusted_registry_configuration() {
  check_8
  check_8_2
  check_8_2_1
  check_8_end
}

community_checks() {
  check_c
  check_c_1
  check_c_1_1
  check_c_2
  check_c_5_3_1; check_c_5_3_2; check_c_5_3_3; check_c_5_3_4
  check_c_end
}

# CIS
cis() {
  host_configuration
  docker_daemon_configuration
  docker_daemon_files
  container_images
  container_runtime
  docker_security_operations
  docker_swarm_configuration
}

cis_level1() {
  host_configuration_level1
  docker_daemon_configuration_level1
  docker_daemon_files_level1
  container_images_level1
  container_runtime_level1
  docker_security_operations_level1
  docker_swarm_configuration_level1
}

# CIS Controls v8 Implementation Groups
cis_controls_v8_ig1() {
  _run_group cis_controls_v8_ig1 ""
}

cis_controls_v8_ig2() {
  _run_group cis_controls_v8_ig2 ""
}

cis_controls_v8_ig3() {
  _run_group cis_controls_v8_ig3 ""
}

# Community contributed
community() {
  community_checks
}

# All
all() {
  cis
  docker_enterprise_configuration
  community
}
