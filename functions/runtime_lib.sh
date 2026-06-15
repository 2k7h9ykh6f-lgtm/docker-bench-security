#!/bin/bash
# --------------------------------------------------------------------------------------------
# Runtime Discovery Module
#
# Provides container runtime detection with three explicit states:
#   available         - Docker CLI + daemon both operational
#   unavailable       - Docker binary missing or daemon unreachable
#   permission_denied - Docker binary exists but user lacks access (e.g. socket)
#
# This module is designed to be sourceable independently for unit testing.
# --------------------------------------------------------------------------------------------

# Runtime state globals
RUNTIME_STATUS=""
RUNTIME_ERROR=""
RUNTIME_TYPE=""

# runtime_discover()
#
# Probe the host for a working container runtime.
# Sets RUNTIME_STATUS, RUNTIME_ERROR, RUNTIME_TYPE globals.
#
# Returns:
#   0 - runtime available
#   1 - runtime unavailable (binary missing or daemon unreachable)
#   2 - permission denied (binary exists, user cannot access)
runtime_discover() {
  RUNTIME_STATUS=""
  RUNTIME_ERROR=""
  RUNTIME_TYPE=""

  # Step 1: Check if docker binary exists on PATH
  if ! command -v docker >/dev/null 2>&1; then
    RUNTIME_STATUS="unavailable"
    RUNTIME_ERROR="docker binary not found in PATH"
    return 1
  fi

  RUNTIME_TYPE="docker"

  # Step 2: Attempt to connect to the daemon
  # Use if/then pattern to be safe under set -e
  local ps_stderr ps_rc
  ps_stderr=$(mktemp 2>/dev/null || echo "/tmp/docker_ps_stderr.$$")
  if docker ps -q >/dev/null 2>"$ps_stderr"; then
    ps_rc=0
  else
    ps_rc=$?
  fi

  if [ $ps_rc -eq 0 ]; then
    RUNTIME_STATUS="available"
    rm -f "$ps_stderr" 2>/dev/null
    return 0
  fi

  # Step 3: Classify the failure
  local stderr_content=""
  if [ -f "$ps_stderr" ]; then
    stderr_content=$(cat "$ps_stderr" 2>/dev/null)
    rm -f "$ps_stderr" 2>/dev/null
  fi

  # Permission denied: exit code 126 (cannot execute) or stderr contains permission-related keywords
  local is_perm_denied=false
  if [ $ps_rc -eq 126 ]; then
    is_perm_denied=true
  elif echo "$stderr_content" | grep -qi "permission denied" 2>/dev/null; then
    is_perm_denied=true
  elif echo "$stderr_content" | grep -qi "connect.*permission" 2>/dev/null; then
    is_perm_denied=true
  elif echo "$stderr_content" | grep -qi "access denied" 2>/dev/null; then
    is_perm_denied=true
  fi

  if [ "$is_perm_denied" = "true" ]; then
    RUNTIME_STATUS="permission_denied"
    RUNTIME_ERROR="insufficient permissions to access docker daemon: ${stderr_content}"
    return 2
  fi

  # All other failures: daemon not running, socket missing, etc.
  RUNTIME_STATUS="unavailable"
  RUNTIME_ERROR="cannot connect to docker daemon: ${stderr_content:-unknown error}"
  return 1
}

# runtime_list_containers(label_filter, include, exclude)
#
# List running containers using the discovered runtime.
#   $1 - label_filter: pre-formatted --filter label=... flags (may be empty)
#   $2 - include: comma-separated patterns to include (may be empty)
#   $3 - exclude: comma-separated patterns to exclude (may be empty)
#
# Output: container names, one per line (suitable for iteration with IFS=$'\n')
# Returns 0 on success, 1 if runtime not available
runtime_list_containers() {
  if [ "$RUNTIME_STATUS" != "available" ]; then
    return 1
  fi

  local label_filter="$1"
  local include="$2"
  local exclude="$3"

  # Find the bench container itself (to exclude it from results)
  local benchcont="nil"
  local c
  for c in $(docker ps 2>/dev/null | sed '1d' | awk '{print $NF}'); do
    if docker inspect --format '{{ .Config.Labels }}' "$c" 2>/dev/null | \
       grep -e 'docker.bench.security' >/dev/null 2>&1; then
      benchcont="$c"
    fi
  done

  local result=""
  if [ -n "$include" ]; then
    local pattern
    pattern=$(echo "$include" | sed 's/,/|/g')
    result=$(docker ps $label_filter 2>/dev/null | sed '1d' | awk '{print $NF}' | grep -v "$benchcont" | grep -E "$pattern")
  elif [ -n "$exclude" ]; then
    local pattern
    pattern=$(echo "$exclude" | sed 's/,/|/g')
    result=$(docker ps $label_filter 2>/dev/null | sed '1d' | awk '{print $NF}' | grep -v "$benchcont" | grep -Ev "$pattern")
  else
    result=$(docker ps $label_filter 2>/dev/null | sed '1d' | awk '{print $NF}' | grep -v "$benchcont")
  fi

  printf "%s" "$result"
  return 0
}

# runtime_list_images(label_filter, include, exclude)
#
# List images using the discovered runtime.
#   $1 - label_filter: pre-formatted --filter label=... flags (may be empty)
#   $2 - include: comma-separated patterns to include (may be empty)
#   $3 - exclude: comma-separated patterns to exclude (may be empty)
#
# Output: image IDs, one per line
# Returns 0 on success, 1 if runtime not available
runtime_list_images() {
  if [ "$RUNTIME_STATUS" != "available" ]; then
    return 1
  fi

  local label_filter="$1"
  local include="$2"
  local exclude="$3"

  # Find the bench image itself (to exclude it from results)
  local benchimagecont="nil"
  local c
  for c in $(docker images 2>/dev/null | sed '1d' | awk '{print $3}'); do
    if docker inspect --format '{{ .Config.Labels }}' "$c" 2>/dev/null | \
       grep -e 'docker.bench.security' >/dev/null 2>&1; then
      benchimagecont="$c"
    fi
  done

  local result=""
  if [ -n "$include" ]; then
    local pattern
    pattern=$(echo "$include" | sed 's/,/|/g')
    result=$(docker images $label_filter 2>/dev/null | sed '1d' | grep -E "$pattern" | awk '{print $3}' | grep -v "$benchimagecont")
  elif [ -n "$exclude" ]; then
    local pattern
    pattern=$(echo "$exclude" | sed 's/,/|/g')
    result=$(docker images $label_filter 2>/dev/null | sed '1d' | grep -Ev "$pattern" | awk '{print $3}' | grep -v "$benchimagecont")
  else
    result=$(docker images -q $label_filter 2>/dev/null | grep -v "$benchimagecont")
  fi

  printf "%s" "$result"
  return 0
}

# runtime_require(section_name)
#
# Guard function for sections that need a working container runtime.
# Returns 0 if runtime is available, 1 otherwise.
# When returning 1, does NOT print anything — caller handles messaging.
runtime_require() {
  if [ "$RUNTIME_STATUS" = "available" ]; then
    return 0
  fi
  return 1
}
