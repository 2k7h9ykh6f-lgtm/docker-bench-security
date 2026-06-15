#!/bin/bash

# Unified rootless Docker detection library.
# Sets globals: DOCKER_MODE, DOCKER_SOCK_PATH, DOCKER_CONFIG_DIR,
#               DOCKER_DAEMON_JSON, DOCKER_SYSTEMD_SCOPE
# All functions are idempotent — safe to call multiple times.

# Defaults (rootful)
DOCKER_MODE="${DOCKER_MODE:-}"
DOCKER_SOCK_PATH="${DOCKER_SOCK_PATH:-}"
DOCKER_CONFIG_DIR="${DOCKER_CONFIG_DIR:-}"
DOCKER_DAEMON_JSON="${DOCKER_DAEMON_JSON:-}"
DOCKER_SYSTEMD_SCOPE="${DOCKER_SYSTEMD_SCOPE:-}"

# Detect whether the Docker daemon is running in rootless mode.
# Sets DOCKER_MODE to "rootless" or "rootful", then resolves all
# dependent paths via the helpers below.
detect_docker_mode() {
  DOCKER_MODE="rootful"

  # Primary signal: docker info reports "rootless" in SecurityOptions
  if docker info -f '{{.SecurityOptions}}' 2>/dev/null | grep -q 'rootless'; then
    DOCKER_MODE="rootless"
  # Fallback: check if the dockerd process is running as a non-root user
  elif _dockerd_runs_as_nonroot; then
    DOCKER_MODE="rootless"
  # Fallback: DOCKER_HOST points to a user-runtime socket
  elif printf '%s' "${DOCKER_HOST:-}" | grep -q '/run/user/'; then
    DOCKER_MODE="rootless"
  fi

  # Resolve all dependent paths
  get_docker_socket_path
  get_docker_config_dir
  get_docker_systemd_scope
}

# Check if any dockerd process is running as a non-root user.
# Returns 0 if a non-root dockerd is found, 1 otherwise.
_dockerd_runs_as_nonroot() {
  for pid in $(pgrep -x dockerd 2>/dev/null); do
    if [ -f "/proc/$pid/status" ]; then
      uid=$(awk '/^Uid:/ { print $2 }' "/proc/$pid/status" 2>/dev/null)
      if [ -n "$uid" ] && [ "$uid" -ne 0 ] 2>/dev/null; then
        return 0
      fi
    fi
  done
  return 1
}

# Resolve the Docker socket path.
# Priority: DOCKER_HOST env > rootless XDG path > default /var/run/docker.sock
get_docker_socket_path() {
  # Explicit DOCKER_HOST always wins (both modes)
  if [ -n "${DOCKER_HOST:-}" ]; then
    case "$DOCKER_HOST" in
      unix://*)
        DOCKER_SOCK_PATH="${DOCKER_HOST#unix://}"
        return
        ;;
    esac
  fi

  if [ "$DOCKER_MODE" = "rootless" ]; then
    local xdg="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    DOCKER_SOCK_PATH="$xdg/docker.sock"
    return
  fi

  # Rootful default
  DOCKER_SOCK_PATH="/var/run/docker.sock"
}

# Resolve the Docker configuration directory and daemon.json path.
# Rootless: ~/.config/docker   Rootful: /etc/docker
get_docker_config_dir() {
  if [ "$DOCKER_MODE" = "rootless" ]; then
    DOCKER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/docker"
  else
    DOCKER_CONFIG_DIR="/etc/docker"
  fi
  DOCKER_DAEMON_JSON="$DOCKER_CONFIG_DIR/daemon.json"
}

# Determine whether systemd units are system-level or user-level.
get_docker_systemd_scope() {
  if [ "$DOCKER_MODE" = "rootless" ]; then
    DOCKER_SYSTEMD_SCOPE="user"
  else
    DOCKER_SYSTEMD_SCOPE="system"
  fi
}

# Check Docker socket accessibility.
# Returns: 0 = accessible, 1 = not found, 2 = permission denied
check_docker_socket_access() {
  local sock="${DOCKER_SOCK_PATH:-/var/run/docker.sock}"

  if [ ! -e "$sock" ]; then
    return 1
  fi

  if [ ! -S "$sock" ]; then
    return 1
  fi

  if [ ! -r "$sock" ] || [ ! -w "$sock" ]; then
    return 2
  fi

  return 0
}

# Return the expected socket ownership for the current mode.
# Rootful: root:docker   Rootless: <current_user>:<current_user>
get_expected_socket_owner() {
  if [ "$DOCKER_MODE" = "rootless" ]; then
    local user
    user="$(id -un)"
    printf '%s:%s' "$user" "$user"
  else
    printf 'root:docker'
  fi
}

# Return the expected config file ownership for the current mode.
# Rootful: root:root   Rootless: <current_user>:<current_user>
get_expected_config_owner() {
  if [ "$DOCKER_MODE" = "rootless" ]; then
    local user
    user="$(id -un)"
    printf '%s:%s' "$user" "$user"
  else
    printf 'root:root'
  fi
}
