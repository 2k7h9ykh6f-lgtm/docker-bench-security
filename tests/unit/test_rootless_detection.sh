#!/bin/bash
# Unit tests for functions/rootless_lib.sh
# Runs without a real Docker daemon — all external commands are stubbed.
#
# Usage: bash tests/unit/test_rootless_detection.sh
# Exit code: 0 = all pass, 1 = failures

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ---------- test harness ----------

pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); printf "  PASS: %s\n" "$1"; }
fail() { TESTS_FAILED=$((TESTS_FAILED + 1)); printf "  FAIL: %s  (got: %s)\n" "$1" "${2:-}"; }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label" "expected='$expected' actual='$actual'"
  fi
}

assert_rc() {
  local label="$1" expected="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" -eq "$actual" ]; then
    pass "$label"
  else
    fail "$label" "expected rc=$expected got rc=$actual"
  fi
}

# Reset globals before each scenario
reset_state() {
  DOCKER_MODE=""
  DOCKER_SOCK_PATH=""
  DOCKER_CONFIG_DIR=""
  DOCKER_DAEMON_JSON=""
  DOCKER_SYSTEMD_SCOPE=""
  unset DOCKER_HOST 2>/dev/null || true
  unset XDG_RUNTIME_DIR 2>/dev/null || true
  unset XDG_CONFIG_HOME 2>/dev/null || true
}

# ---------- source the library ----------
. "$SCRIPT_DIR/functions/rootless_lib.sh"

# ================================================================
# Scenario 1: Rootful Docker (default)
# ================================================================
printf "\n--- Scenario 1: Rootful Docker (default) ---\n"
reset_state

# Stub: docker info shows no rootless
docker() {
  case "$*" in
    "info -f {{.SecurityOptions}}")
      echo "[name=seccomp,profile=default name=cgroupns]"
      ;;
  esac
}
# Stub: no non-root dockerd
pgrep() { return 1; }
# Stub: id
id() {
  case "$1" in
    -u) echo "0" ;;
    -un) echo "root" ;;
  esac
}
export -f docker pgrep id

detect_docker_mode

assert_eq "mode=rootful"           "rootful"                "$DOCKER_MODE"
assert_eq "sock=/var/run/docker.sock" "/var/run/docker.sock" "$DOCKER_SOCK_PATH"
assert_eq "config_dir=/etc/docker" "/etc/docker"            "$DOCKER_CONFIG_DIR"
assert_eq "daemon_json"            "/etc/docker/daemon.json" "$DOCKER_DAEMON_JSON"
assert_eq "systemd_scope=system"   "system"                 "$DOCKER_SYSTEMD_SCOPE"

# ================================================================
# Scenario 2: Rootless Docker (via docker info)
# ================================================================
printf "\n--- Scenario 2: Rootless Docker ---\n"
reset_state
export XDG_RUNTIME_DIR="/run/user/1000"
export HOME="/home/testuser"

docker() {
  case "$*" in
    "info -f {{.SecurityOptions}}")
      echo "[name=seccomp,profile=default name=rootless]"
      ;;
  esac
}
id() {
  case "$1" in
    -u) echo "1000" ;;
    -un) echo "testuser" ;;
  esac
}
export -f docker id

detect_docker_mode

assert_eq "mode=rootless"                "rootless"                            "$DOCKER_MODE"
assert_eq "sock=/run/user/1000/docker.sock" "/run/user/1000/docker.sock"      "$DOCKER_SOCK_PATH"
assert_eq "config_dir=~/.config/docker"  "/home/testuser/.config/docker"      "$DOCKER_CONFIG_DIR"
assert_eq "daemon_json"                  "/home/testuser/.config/docker/daemon.json" "$DOCKER_DAEMON_JSON"
assert_eq "systemd_scope=user"           "user"                               "$DOCKER_SYSTEMD_SCOPE"

# ================================================================
# Scenario 3: Socket not found
# ================================================================
printf "\n--- Scenario 3: Socket not found ---\n"
reset_state

docker() {
  case "$*" in
    "info -f {{.SecurityOptions}}")
      echo "[name=seccomp,profile=default]"
      ;;
  esac
}
pgrep() { return 1; }
id() {
  case "$1" in
    -u) echo "0" ;;
    -un) echo "root" ;;
  esac
}
export -f docker pgrep id

detect_docker_mode
# Point to a guaranteed-nonexistent path
DOCKER_SOCK_PATH="/nonexistent/docker.sock"

rc=0
check_docker_socket_access || rc=$?
assert_rc "socket not found returns 1" 1 "$rc"

# ================================================================
# Scenario 4: Permission denied (socket exists, not readable)
# ================================================================
printf "\n--- Scenario 4: Permission denied ---\n"

TMPDIR_TEST=$(mktemp -d)
SOCK_FILE="$TMPDIR_TEST/docker.sock"

# Create a real unix socket via a background socat or python, or
# simulate with a named pipe (simplest portable approach).
# For the -S test we need an actual socket. Use python if available.
_created_sock=false
if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind('$SOCK_FILE')
s.listen(1)
" &
  _sock_pid=$!
  sleep 0.2
  _created_sock=true
fi

if $_created_sock && [ -S "$SOCK_FILE" ]; then
  chmod 000 "$SOCK_FILE"
  DOCKER_SOCK_PATH="$SOCK_FILE"

  rc=0
  check_docker_socket_access || rc=$?
  assert_rc "permission denied returns 2" 2 "$rc"

  kill "$_sock_pid" 2>/dev/null
  wait "$_sock_pid" 2>/dev/null
else
  TESTS_RUN=$((TESTS_RUN + 1))
  pass "permission denied (skipped — no python3 for socket creation)"
fi
rm -rf "$TMPDIR_TEST"

# ================================================================
# Scenario 5: DOCKER_HOST override
# ================================================================
printf "\n--- Scenario 5: DOCKER_HOST override ---\n"
reset_state
export DOCKER_HOST="unix:///custom/path/docker.sock"

docker() {
  case "$*" in
    "info -f {{.SecurityOptions}}")
      echo "[name=seccomp,profile=default]"
      ;;
  esac
}
pgrep() { return 1; }
id() {
  case "$1" in
    -u) echo "0" ;;
    -un) echo "root" ;;
  esac
}
export -f docker pgrep id

detect_docker_mode

assert_eq "mode=rootful (DOCKER_HOST set)" "rootful"                      "$DOCKER_MODE"
assert_eq "sock from DOCKER_HOST"          "/custom/path/docker.sock"     "$DOCKER_SOCK_PATH"

# Also test DOCKER_HOST with rootless
reset_state
export DOCKER_HOST="unix:///custom/path/docker.sock"
export HOME="/home/testuser"

docker() {
  case "$*" in
    "info -f {{.SecurityOptions}}")
      echo "[name=rootless]"
      ;;
  esac
}
id() {
  case "$1" in
    -u) echo "1000" ;;
    -un) echo "testuser" ;;
  esac
}
export -f docker id

detect_docker_mode

assert_eq "rootless + DOCKER_HOST"  "/custom/path/docker.sock"  "$DOCKER_SOCK_PATH"

# ================================================================
# Scenario 6: Rootless with custom XDG_CONFIG_HOME
# ================================================================
printf "\n--- Scenario 6: Custom XDG_CONFIG_HOME ---\n"
reset_state
export XDG_RUNTIME_DIR="/run/user/1000"
export XDG_CONFIG_HOME="/custom/config"
export HOME="/home/testuser"

docker() {
  case "$*" in
    "info -f {{.SecurityOptions}}")
      echo "[name=rootless]"
      ;;
  esac
}
id() {
  case "$1" in
    -u) echo "1000" ;;
    -un) echo "testuser" ;;
  esac
}
export -f docker id

detect_docker_mode

assert_eq "config_dir from XDG_CONFIG_HOME" "/custom/config/docker"              "$DOCKER_CONFIG_DIR"
assert_eq "daemon_json from XDG_CONFIG_HOME" "/custom/config/docker/daemon.json" "$DOCKER_DAEMON_JSON"

# ================================================================
# Scenario 7: Ownership helpers
# ================================================================
printf "\n--- Scenario 7: Ownership helpers ---\n"

DOCKER_MODE="rootful"
id() {
  case "$1" in
    -un) echo "root" ;;
  esac
}
export -f id
assert_eq "rootful socket owner"  "root:docker" "$(get_expected_socket_owner)"
assert_eq "rootful config owner"  "root:root"   "$(get_expected_config_owner)"

DOCKER_MODE="rootless"
id() {
  case "$1" in
    -un) echo "testuser" ;;
  esac
}
export -f id
assert_eq "rootless socket owner" "testuser:testuser" "$(get_expected_socket_owner)"
assert_eq "rootless config owner" "testuser:testuser" "$(get_expected_config_owner)"

# ================================================================
# Scenario 8: Fallback — DOCKER_HOST pattern detection
# ================================================================
printf "\n--- Scenario 8: Fallback via DOCKER_HOST /run/user/ pattern ---\n"
reset_state
export DOCKER_HOST="unix:///run/user/1000/docker.sock"
export XDG_RUNTIME_DIR="/run/user/1000"
export HOME="/home/testuser"

# docker info does NOT report rootless, pgrep finds nothing
docker() {
  case "$*" in
    "info -f {{.SecurityOptions}}")
      echo "[name=seccomp,profile=default]"
      ;;
  esac
}
pgrep() { return 1; }
id() {
  case "$1" in
    -u) echo "1000" ;;
    -un) echo "testuser" ;;
  esac
}
export -f docker pgrep id

detect_docker_mode

assert_eq "fallback detects rootless" "rootless" "$DOCKER_MODE"
assert_eq "sock from DOCKER_HOST"     "/run/user/1000/docker.sock" "$DOCKER_SOCK_PATH"

# ---------- summary ----------
printf "\n========================================\n"
printf "Tests: %d  Passed: %d  Failed: %d\n" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf "========================================\n"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
