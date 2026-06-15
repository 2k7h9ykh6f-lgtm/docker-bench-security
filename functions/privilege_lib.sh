#!/bin/bash
# Privilege and capability detection for degraded-mode operation.
# Probes once at startup; check scripts read these flags instead of re-probing.

# --- Root ---
IS_ROOT=0
[ "$(id -u)" = "0" ] && IS_ROOT=1

# --- Docker socket ---
HAS_DOCKER_SOCKET=0
docker_socket="/var/run/docker.sock"
[ -S "$docker_socket" ] && HAS_DOCKER_SOCKET=1

# --- Docker connectivity (socket exists + daemon responds) ---
HAS_DOCKER=0
if [ "$HAS_DOCKER_SOCKET" -eq 1 ] && docker ps -q >/dev/null 2>&1; then
  HAS_DOCKER=1
fi

# --- Audit capability (auditctl present + permitted) ---
CAN_AUDIT=0
if command -v auditctl >/dev/null 2>&1 && auditctl -l >/dev/null 2>&1; then
  CAN_AUDIT=1
fi

# --- Helper: check if a file is readable ---
# Returns: 0=readable, 1=not found, 2=permission denied
check_file_access() {
  local f="$1"
  if [ ! -e "$f" ]; then
    return 1
  fi
  if [ ! -r "$f" ]; then
    return 2
  fi
  return 0
}

readonly IS_ROOT HAS_DOCKER_SOCKET HAS_DOCKER CAN_AUDIT
