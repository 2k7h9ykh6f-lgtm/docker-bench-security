#!/bin/bash
# perm_lib.sh — Capability detection and graceful degradation
#
# Probes the runtime environment once at startup and sets boolean flags.
# Individual checks (or whole groups) call require_cap() to skip themselves
# cleanly when a prerequisite is missing.  Skipped checks are counted
# separately and do NOT affect the pass/warn score.
#
# Capabilities
#   ROOT        — effective uid is 0
#   DOCKER      — `docker ps` succeeds (socket accessible, daemon reachable)
#   AUDIT       — auditctl is available OR /etc/audit/audit.rules is readable
#   CONFIG_READ — Docker daemon config file is readable (or absent)

# ── Internal state ──────────────────────────────────────────────────────────

# Set by probe_capabilities().  Values: "yes" | "no"
_CAP_ROOT="no"
_CAP_DOCKER="no"
_CAP_AUDIT="no"
_CAP_CONFIG_READ="no"

# Degraded mode flag.  When "yes" the main script must NOT call any docker
# command to build container/image lists or identify the bench container.
DEGRADED_MODE="no"

# Populated by probe_capabilities() for diagnostic output.
_CAP_DOCKER_REASON=""
_CAP_AUDIT_REASON=""

# ── Low-level probes ────────────────────────────────────────────────────────

_probe_root() {
  if [ "$(id -u)" = "0" ]; then
    _CAP_ROOT="yes"
  fi
}

_probe_docker() {
  # The canonical connectivity test used throughout the project.
  if docker ps -q >/dev/null 2>&1; then
    _CAP_DOCKER="yes"
    _CAP_DOCKER_REASON="ok"
    return
  fi

  # Give the operator a useful diagnostic instead of a bare "cannot connect".
  if [ ! -e /var/run/docker.sock ]; then
    _CAP_DOCKER_REASON="socket /var/run/docker.sock not found"
  elif [ ! -r /var/run/docker.sock ] || [ ! -w /var/run/docker.sock ]; then
    _CAP_DOCKER_REASON="no read/write permission on /var/run/docker.sock"
  else
    _CAP_DOCKER_REASON="daemon unreachable (docker ps failed)"
  fi
}

_probe_audit() {
  if command -v auditctl >/dev/null 2>&1; then
    _CAP_AUDIT="yes"
    _CAP_AUDIT_REASON="auditctl available"
    return
  fi
  if [ -r "$auditrules" ]; then
    _CAP_AUDIT="yes"
    _CAP_AUDIT_REASON="audit.rules readable"
    return
  fi
  _CAP_AUDIT_REASON="no auditctl and $auditrules not readable"
}

_probe_config_read() {
  # CONFIG_READ is "yes" when the configuration is usable:
  #   • explicit CONFIG_FILE is readable, OR
  #   • well-known paths are readable, OR
  #   • no config file exists at all (nothing to read → safe default)
  if [ -n "$CONFIG_FILE" ] && [ "$CONFIG_FILE" != "/dev/null" ]; then
    if [ -r "$CONFIG_FILE" ]; then
      _CAP_CONFIG_READ="yes"
      return
    fi
    # File is set but unreadable — check if it even exists
    if [ -f "$CONFIG_FILE" ]; then
      # Exists but not readable → genuine config-read failure
      return
    fi
    # CONFIG_FILE was set to a path that doesn't exist (e.g. before
    # main() calls get_docker_configuration_file).  Fall through to
    # the well-known path checks below.
  fi
  if [ -r /etc/docker/daemon.json ]; then
    _CAP_CONFIG_READ="yes"
    return
  fi
  # No config found at all — treat as readable (nothing to trip over).
  _CAP_CONFIG_READ="yes"
}

# ── Public API ───────────────────────────────────────────────────────────────

# probe_capabilities
#   Run all probes.  Safe to call more than once (idempotent).
probe_capabilities() {
  _probe_root
  _probe_docker
  _probe_audit
  _probe_config_read
}

# has_cap <CAP>
#   Returns 0 (true) if the named capability is available, 1 otherwise.
#   Usage:  if has_cap DOCKER; then ... fi
has_cap() {
  case "$1" in
    ROOT)        [ "$_CAP_ROOT"        = "yes" ] ;;
    DOCKER)      [ "$_CAP_DOCKER"      = "yes" ] ;;
    AUDIT)       [ "$_CAP_AUDIT"       = "yes" ] ;;
    CONFIG_READ) [ "$_CAP_CONFIG_READ" = "yes" ] ;;
    *)           return 1 ;;
  esac
}

# require_cap <CAP> <check_id> <check_desc>
#   Guard for use inside check functions.  When the capability is missing:
#     • emits [SKIP] to the formatted log
#     • records the skip in JSON output via logcheckresult
#     • returns 1 so the caller can `return` immediately
#   When the capability is present, returns 0 and the check continues.
#
#   Usage:
#     check_X_Y() {
#       local id="X.Y"  desc="..."  check="X.Y - ..."
#       starttestjson "$id" "$desc"
#       require_cap "ROOT" "$id" "$desc" || return
#       ... actual check logic ...
#     }
require_cap() {
  if has_cap "$1"; then
    return 0
  fi
  local cap="$1"
  local check_id="$2"
  local check_desc="$3"
  skip -c "$check_id - $check_desc"
  logcheckresult "SKIP" "Requires $cap capability"
  return 1
}

# is_degraded
#   Returns 0 if the script is running in degraded mode (no docker).
is_degraded() {
  [ "$DEGRADED_MODE" = "yes" ]
}

# log_capabilities
#   Print a structured capability report.  Called after yell_info.
log_capabilities() {
  logit "\n${bldylw}Runtime capabilities${txtrst}"

  _cap_line() {
    local name="$1"  val="$2"  reason="$3"
    if [ "$val" = "yes" ]; then
      logit "  ${bldgrn}[ OK ]${txtrst} $name"
    else
      if [ -n "$reason" ]; then
        logit "  ${bldred}[ MISS ]${txtrst} $name — $reason"
      else
        logit "  ${bldred}[ MISS ]${txtrst} $name"
      fi
    fi
  }

  _cap_line "ROOT"        "$_CAP_ROOT"
  _cap_line "DOCKER"      "$_CAP_DOCKER"      "$_CAP_DOCKER_REASON"
  _cap_line "AUDIT"       "$_CAP_AUDIT"       "$_CAP_AUDIT_REASON"
  _cap_line "CONFIG_READ" "$_CAP_CONFIG_READ"

  if [ "$DEGRADED_MODE" = "yes" ]; then
    logit "\n  ${bldmag}Running in DEGRADED mode — Docker-dependent checks will be skipped.${txtrst}"
  fi
  logit ""
}
