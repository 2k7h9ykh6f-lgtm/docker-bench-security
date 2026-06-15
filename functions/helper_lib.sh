#!/bin/bash

# Returns the absolute path of a given string
abspath () { case "$1" in /*)printf "%s\n" "$1";; *)printf "%s\n" "$PWD/$1";; esac; }

# Audit rules default path
auditrules="/etc/audit/audit.rules"

# Docker environment defaults (overridden by detect_docker_environment)
DOCKER_CONFIG_DIR="/etc/docker"
DOCKER_SYSTEMD_SCOPE="system"

# Check for required program(s)
req_programs() {
  for p in $1; do
    command -v "$p" >/dev/null 2>&1 || { printf "Required program not found: %s\n" "$p"; exit 1; }
  done
  if command -v jq >/dev/null 2>&1; then
    HAVE_JQ=true
  else
    HAVE_JQ=false
  fi
  if command -v ss >/dev/null 2>&1; then
    netbin=ss
    return
  fi
  if command -v netstat >/dev/null 2>&1; then
    netbin=netstat
    return
  fi
  echo "ss or netstat command not found."
  exit 1
}

# Compares versions of software of the format X.Y.Z
do_version_check() {
  [ "$1" = "$2" ] && return 10

  ver1front=$(printf "%s" "$1" | cut -d "." -f -1)
  ver1back=$(printf "%s" "$1" | cut -d "." -f 2-)
  ver2front=$(printf "%s" "$2" | cut -d "." -f -1)
  ver2back=$(printf "%s" "$2" | cut -d "." -f 2-)

  if [ "$ver1front" != "$1" ] || [ "$ver2front" != "$2" ]; then
    [ "$ver1front" -gt "$ver2front" ] && return 11
    [ "$ver1front" -lt "$ver2front" ] && return 9

    [ "$ver1front" = "$1" ] || [ -z "$ver1back" ] && ver1back=0
    [ "$ver2front" = "$2" ] || [ -z "$ver2back" ] && ver2back=0
      do_version_check "$ver1back" "$ver2back"
      return $?
  fi
  [ "$1" -gt "$2" ] && return 11 || return 9
}

# Extracts commandline args from the newest running processes named like the first parameter
get_command_line_args() {
  PROC="$1"

  for PID in $(pgrep -f -n "$PROC"); do
    tr "\0" " " < /proc/"$PID"/cmdline
  done
}

# Extract the cumulative command line arguments for the docker daemon
#
# If specified multiple times, all matches are returned.
# Accounts for long and short variants, call with short option.
# Does not account for option defaults or implicit options.
get_docker_cumulative_command_line_args() {
  OPTION="$1"

  line_arg="dockerd"
  if ! get_command_line_args "docker daemon" >/dev/null 2>&1 ; then
    line_arg="docker daemon"
  fi

  get_command_line_args "$line_arg" |
  # normalize known long options to their short versions
  sed \
    -e 's/\-\-debug/-D/g' \
    -e 's/\-\-host/-H/g' \
    -e 's/\-\-log-level/-l/g' \
    -e 's/\-\-version/-v/g' \
    |
    # normalize parameters separated by space(s) to -O=VALUE
    sed \
      -e 's/\-\([DHlv]\)[= ]\([^- ][^ ]\)/-\1=\2/g' \
      |
    # get the last interesting option
    tr ' ' "\n" |
    grep "^${OPTION}" |
    # normalize quoting of values
    sed \
      -e 's/"//g' \
      -e "s/'//g"
}

# Extract the effective command line arguments for the docker daemon
#
# Accounts for multiple specifications, takes the last option.
# Accounts for long and short variants, call with short option
# Does not account for option default or implicit options.
get_docker_effective_command_line_args() {
  OPTION="$1"
  get_docker_cumulative_command_line_args "$OPTION" | tail -n1
}

get_docker_configuration_file() {
  FILE="$(get_docker_effective_command_line_args '--config-file' | \
    sed 's/.*=//g')"

  if [ -f "$FILE" ]; then
    CONFIG_FILE="$FILE"
    return
  fi
  if [ -f "${DOCKER_CONFIG_DIR}/daemon.json" ]; then
    CONFIG_FILE="${DOCKER_CONFIG_DIR}/daemon.json"
    return
  fi
  CONFIG_FILE='/dev/null'
}

get_docker_configuration_file_args() {
  OPTION="$1"

  get_docker_configuration_file

  if "$HAVE_JQ"; then
    jq --monochrome-output --raw-output "if has(\"${OPTION}\") then .[\"${OPTION}\"] else \"\" end" "$CONFIG_FILE"
  else
    cat "$CONFIG_FILE" | tr , '\n' | grep "$OPTION" | sed 's/.*://g' | tr -d '" ',
  fi
}

get_service_file() {
  SERVICE="$1"
  SCOPE="${2:-$DOCKER_SYSTEMD_SCOPE}"

  # User-level systemd paths (rootless Docker)
  if [ "$SCOPE" = "user" ]; then
    if [ -f "${HOME}/.config/systemd/user/$SERVICE" ]; then
      echo "${HOME}/.config/systemd/user/$SERVICE"
      return
    fi
    if [ -f "/usr/lib/systemd/user/$SERVICE" ]; then
      echo "/usr/lib/systemd/user/$SERVICE"
      return
    fi
    if command -v systemctl >/dev/null 2>&1; then
      local fragpath
      fragpath="$(systemctl --user show -p FragmentPath "$SERVICE" 2>/dev/null | sed 's/.*=//')"
      if [ -n "$fragpath" ]; then
        echo "$fragpath"
        return
      fi
    fi
  fi

  # System-level systemd paths (rootful Docker, or fallback)
  if [ -f "/etc/systemd/system/$SERVICE" ]; then
    echo "/etc/systemd/system/$SERVICE"
    return
  fi
  if [ -f "/lib/systemd/system/$SERVICE" ]; then
    echo "/lib/systemd/system/$SERVICE"
    return
  fi
  if find /run -name "$SERVICE" 2> /dev/null 1>&2; then
    find /run -name "$SERVICE" | head -n1
    return
  fi
  if [ "$(systemctl show -p FragmentPath "$SERVICE" 2>/dev/null | sed 's/.*=//')" != "" ]; then
    systemctl show -p FragmentPath "$SERVICE" | sed 's/.*=//'
    return
  fi
  echo "/usr/lib/systemd/system/$SERVICE"
}

yell_info() {
yell "# --------------------------------------------------------------------------------------------
# Docker Bench for Security v$version
#
# Docker, Inc. (c) 2015-$(date +"%Y")
#
# Checks for dozens of common best-practices around deploying Docker containers in production.
# Based on the CIS Docker Benchmark 1.6.0.
# --------------------------------------------------------------------------------------------"
}

# detect_docker_environment() - Unified Docker environment probe
#
# Detects whether Docker is running in rootful or rootless mode and resolves
# the actual paths for the Docker socket, containerd socket, configuration
# directory, and systemd service scope.
#
# Sets the following global variables:
#   DOCKER_IS_ROOTLESS      - "true" if rootless, "false" if rootful
#   DOCKER_SOCKET_PATH      - Resolved Docker socket path
#   DOCKER_SOCKET_ACCESS    - "ok", "missing", or "permission_denied"
#   CONTAINERD_SOCKET_PATH  - Resolved containerd socket path
#   DOCKER_CONFIG_DIR       - Docker config directory
#   DOCKER_SYSTEMD_SCOPE    - "system" or "user"
#
# Detection strategy (in order of precedence):
#   1. Parse `docker info` SecurityOptions for "rootless"
#   2. Check DOCKER_HOST environment variable for unix socket path
#   3. If rootless and no DOCKER_HOST, try $XDG_RUNTIME_DIR/docker.sock
#   4. Fall back to default /var/run/docker.sock (rootful default)
#
# Commands actually executed:
#   - docker info (piped to grep for "rootless")
#   - shell builtins [ -S / -r / -w ] on candidate socket paths
#   No systemctl, stat, or find calls are made by this probe.
#
# Compatibility:
#   When Docker runs as a traditional rootful daemon and DOCKER_HOST is unset,
#   all resolved paths match the original hardcoded defaults.
detect_docker_environment() {
  # --- Step 1: Detect rootless mode via docker info ---
  DOCKER_IS_ROOTLESS="false"
  if docker info 2>/dev/null | grep -qi 'rootless'; then
    DOCKER_IS_ROOTLESS="true"
  fi

  # --- Step 2: Resolve Docker socket path ---
  DOCKER_SOCKET_PATH=""
  DOCKER_SOCKET_ACCESS="missing"

  # 2a: Check DOCKER_HOST environment variable for a unix socket
  if [ -n "$DOCKER_HOST" ]; then
    case "$DOCKER_HOST" in
      unix://*)
        DOCKER_SOCKET_PATH="${DOCKER_HOST#unix://}"
        ;;
    esac
  fi

  # 2b: If rootless and DOCKER_HOST didn't provide a socket, try XDG_RUNTIME_DIR
  if [ -z "$DOCKER_SOCKET_PATH" ] && [ "$DOCKER_IS_ROOTLESS" = "true" ]; then
    if [ -n "$XDG_RUNTIME_DIR" ]; then
      DOCKER_SOCKET_PATH="$XDG_RUNTIME_DIR/docker.sock"
    fi
  fi

  # 2c: Fall back to default rootful socket
  if [ -z "$DOCKER_SOCKET_PATH" ]; then
    DOCKER_SOCKET_PATH="/var/run/docker.sock"
  fi

  # --- Step 3: Check socket accessibility ---
  if [ -S "$DOCKER_SOCKET_PATH" ]; then
    if [ -r "$DOCKER_SOCKET_PATH" ] && [ -w "$DOCKER_SOCKET_PATH" ]; then
      DOCKER_SOCKET_ACCESS="ok"
    else
      DOCKER_SOCKET_ACCESS="permission_denied"
    fi
  else
    DOCKER_SOCKET_ACCESS="missing"
  fi

  # --- Step 4: Resolve containerd socket path ---
  if [ "$DOCKER_IS_ROOTLESS" = "true" ] && [ -n "$XDG_RUNTIME_DIR" ]; then
    CONTAINERD_SOCKET_PATH="$XDG_RUNTIME_DIR/containerd/containerd.sock"
    if [ ! -S "$CONTAINERD_SOCKET_PATH" ]; then
      CONTAINERD_SOCKET_PATH="$XDG_RUNTIME_DIR/docker/containerd/containerd.sock"
    fi
  else
    CONTAINERD_SOCKET_PATH="/run/containerd/containerd.sock"
  fi

  # --- Step 5: Resolve Docker config directory ---
  if [ "$DOCKER_IS_ROOTLESS" = "true" ]; then
    DOCKER_CONFIG_DIR="${HOME}/.config/docker"
  else
    DOCKER_CONFIG_DIR="/etc/docker"
  fi

  # --- Step 6: Set systemd service scope ---
  if [ "$DOCKER_IS_ROOTLESS" = "true" ]; then
    DOCKER_SYSTEMD_SCOPE="user"
  else
    DOCKER_SYSTEMD_SCOPE="system"
  fi
}
