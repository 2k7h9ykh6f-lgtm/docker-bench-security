#!/bin/bash
# test_rootless_detection.sh - Standalone tests for detect_docker_environment()
#
# Runs five scenarios:
#   1. rootful (default)       - no DOCKER_HOST, socket at /var/run/docker.sock
#   2. rootless via DOCKER_HOST - DOCKER_HOST set, docker info reports rootless
#   3. socket missing          - DOCKER_HOST points to nonexistent socket
#   4. permission denied       - socket exists but is not readable/writable
#   5. rootless via XDG_RUNTIME_DIR - no DOCKER_HOST, XDG_RUNTIME_DIR set
#
# Usage: bash tests/test_rootless_detection.sh
# Exit code: 0 if all pass, 1 if any fail

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Provide stubs for variables/functions that helper_lib.sh references
HAVE_JQ=false
version="test"
nocolor="nocolor"
logger="/dev/null"

# Stub yell_info so sourcing doesn't print banner
yell() { :; }
yell_info() { :; }

# Stub out functions that call external programs we don't need
req_programs() { :; }

# Source the helper library
# shellcheck disable=SC1091
. "$SCRIPT_DIR/functions/helper_lib.sh"

assert_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    printf "  \033[1;32mPASS\033[0m  %s (expected=%s)\n" "$desc" "$expected"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  \033[1;31mFAIL\033[0m  %s (expected=%s, got=%s)\n" "$desc" "$expected" "$actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Create a temporary directory for test artifacts
TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# Create a fake docker command that outputs controlled "docker info" text
create_fake_docker() {
  local tmpdir="$1"
  local info_output="$2"
  local bindir="$tmpdir/bin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<FAKEEOF
#!/bin/sh
case "\$1" in
  info)
    printf '%s\n' "$info_output"
    ;;
  ps)
    # no-op
    ;;
  *)
    # no-op
    ;;
esac
exit 0
FAKEEOF
  chmod +x "$bindir/docker"
  echo "$bindir"
}

# Create a Unix socket at the given path using Python
create_socket() {
  local sockpath="$1"
  mkdir -p "$(dirname "$sockpath")"
  python3 -c "
import socket, os
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    os.unlink('$sockpath')
except OSError:
    pass
s.bind('$sockpath')
" 2>/dev/null
}

# Helper: reset environment between scenarios
reset_env() {
  unset DOCKER_HOST 2>/dev/null
  unset XDG_RUNTIME_DIR 2>/dev/null
  # Reset detection globals to known defaults
  DOCKER_IS_ROOTLESS="false"
  DOCKER_SOCKET_PATH=""
  DOCKER_SOCKET_ACCESS="missing"
  CONTAINERD_SOCKET_PATH=""
  DOCKER_CONFIG_DIR="/etc/docker"
  DOCKER_SYSTEMD_SCOPE="system"
}

# ============================================================
printf "\n\033[1;33m=== Scenario 1: rootful (default) ===\033[0m\n"
# ============================================================

reset_env

T1_DIR="$TMPDIR_BASE/s1"
T1_BINDIR=$(create_fake_docker "$T1_DIR" "Server Version: 24.0.0
Storage Driver: overlay2
Security Options: seccomp apparmor")

# Put fake docker at front of PATH
export PATH="$T1_BINDIR:$PATH"

detect_docker_environment

assert_eq "DOCKER_IS_ROOTLESS" "false" "$DOCKER_IS_ROOTLESS"
assert_eq "DOCKER_SOCKET_PATH" "/var/run/docker.sock" "$DOCKER_SOCKET_PATH"
assert_eq "DOCKER_SYSTEMD_SCOPE" "system" "$DOCKER_SYSTEMD_SCOPE"
assert_eq "DOCKER_CONFIG_DIR" "/etc/docker" "$DOCKER_CONFIG_DIR"
assert_eq "CONTAINERD_SOCKET_PATH" "/run/containerd/containerd.sock" "$CONTAINERD_SOCKET_PATH"

# ============================================================
printf "\n\033[1;33m=== Scenario 2: rootless via DOCKER_HOST ===\033[0m\n"
# ============================================================

reset_env

T2_DIR="$TMPDIR_BASE/s2"
T2_SOCK="$T2_DIR/docker.sock"
create_socket "$T2_SOCK"

T2_BINDIR=$(create_fake_docker "$T2_DIR" "Server Version: 24.0.0
Storage Driver: overlay2
Security Options: rootless name=seccomp,profile=default")

export PATH="$T2_BINDIR:$PATH"
export DOCKER_HOST="unix://$T2_SOCK"
export XDG_RUNTIME_DIR="$T2_DIR"

detect_docker_environment

assert_eq "DOCKER_IS_ROOTLESS" "true" "$DOCKER_IS_ROOTLESS"
assert_eq "DOCKER_SOCKET_PATH" "$T2_SOCK" "$DOCKER_SOCKET_PATH"
assert_eq "DOCKER_SYSTEMD_SCOPE" "user" "$DOCKER_SYSTEMD_SCOPE"
assert_eq "DOCKER_CONFIG_DIR" "${HOME}/.config/docker" "$DOCKER_CONFIG_DIR"

# Socket access check
if [ -S "$T2_SOCK" ]; then
  assert_eq "DOCKER_SOCKET_ACCESS" "ok" "$DOCKER_SOCKET_ACCESS"
else
  printf "  \033[1;33mSKIP\033[0m  DOCKER_SOCKET_ACCESS (no python3 to create real socket)\n"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

unset DOCKER_HOST
unset XDG_RUNTIME_DIR

# ============================================================
printf "\n\033[1;33m=== Scenario 3: socket missing ===\033[0m\n"
# ============================================================

reset_env

T3_DIR="$TMPDIR_BASE/s3"
T3_BINDIR=$(create_fake_docker "$T3_DIR" "Server Version: 24.0.0
Security Options: rootless")

export PATH="$T3_BINDIR:$PATH"
export DOCKER_HOST="unix://$TMPDIR_BASE/nonexistent/docker.sock"

detect_docker_environment

assert_eq "DOCKER_IS_ROOTLESS" "true" "$DOCKER_IS_ROOTLESS"
assert_eq "DOCKER_SOCKET_PATH" "$TMPDIR_BASE/nonexistent/docker.sock" "$DOCKER_SOCKET_PATH"
assert_eq "DOCKER_SOCKET_ACCESS" "missing" "$DOCKER_SOCKET_ACCESS"

unset DOCKER_HOST

# ============================================================
printf "\n\033[1;33m=== Scenario 4: permission denied ===\033[0m\n"
# ============================================================

reset_env

T4_DIR="$TMPDIR_BASE/s4"
T4_SOCK="$T4_DIR/docker.sock"
create_socket "$T4_SOCK"

T4_BINDIR=$(create_fake_docker "$T4_DIR" "Server Version: 24.0.0
Security Options: rootless")

if [ ! -S "$T4_SOCK" ]; then
  printf "  \033[1;33mSKIP\033[0m  permission_denied (no python3 to create real socket)\n"
  TESTS_TOTAL=$((TESTS_TOTAL + 2))
  TESTS_PASSED=$((TESTS_PASSED + 2))
else
  chmod 000 "$T4_SOCK"
  export PATH="$T4_BINDIR:$PATH"
  export DOCKER_HOST="unix://$T4_SOCK"

  detect_docker_environment

  assert_eq "DOCKER_SOCKET_ACCESS" "permission_denied" "$DOCKER_SOCKET_ACCESS"
  assert_eq "DOCKER_SOCKET_PATH" "$T4_SOCK" "$DOCKER_SOCKET_PATH"

  # Restore permissions for cleanup
  chmod 644 "$T4_SOCK"
  unset DOCKER_HOST
fi

# ============================================================
printf "\n\033[1;33m=== Scenario 5: rootless via XDG_RUNTIME_DIR (no DOCKER_HOST) ===\033[0m\n"
# ============================================================

reset_env

T5_DIR="$TMPDIR_BASE/s5"
T5_SOCK="$T5_DIR/docker.sock"
create_socket "$T5_SOCK"

T5_BINDIR=$(create_fake_docker "$T5_DIR" "Server Version: 24.0.0
Security Options: rootless")

export PATH="$T5_BINDIR:$PATH"
unset DOCKER_HOST
export XDG_RUNTIME_DIR="$T5_DIR"

detect_docker_environment

assert_eq "DOCKER_IS_ROOTLESS" "true" "$DOCKER_IS_ROOTLESS"
assert_eq "DOCKER_SOCKET_PATH" "$T5_DIR/docker.sock" "$DOCKER_SOCKET_PATH"

if [ -S "$T5_SOCK" ]; then
  assert_eq "DOCKER_SOCKET_ACCESS" "ok" "$DOCKER_SOCKET_ACCESS"
fi

unset XDG_RUNTIME_DIR

# ============================================================
# Summary
# ============================================================
printf "\n\033[1;33m=== Results ===\033[0m\n"
printf "Total: %d | Passed: %d | Failed: %d\n" "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
  printf "\033[1;31mFAILED\033[0m\n"
  exit 1
fi
printf "\033[1;32mALL TESTS PASSED\033[0m\n"
exit 0
