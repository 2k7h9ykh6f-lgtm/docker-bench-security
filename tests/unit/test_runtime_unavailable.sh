#!/bin/bash
# --------------------------------------------------------------------------------------------
# Test: Runtime unavailable (docker binary missing or daemon unreachable)
# --------------------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/test_framework.sh"

# --- Scenario A: docker binary not found ---

describe "runtime_discover - docker binary missing"

# Use a clean PATH that does NOT include docker
SAFE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$SAFE_PATH"

# Also remove any docker that might be on the safe path by using a temp dir
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT
export PATH="$MOCK_DIR:$SAFE_PATH"

. "$SCRIPT_DIR/../../functions/runtime_lib.sh"

runtime_discover; rc=$?

assert_return_code 1 $rc "runtime_discover returns 1 when binary missing"
assert_eq "unavailable" "$RUNTIME_STATUS" "RUNTIME_STATUS is 'unavailable'"
assert_contains "$RUNTIME_ERROR" "not found" "RUNTIME_ERROR mentions 'not found'"
assert_empty "$RUNTIME_TYPE" "RUNTIME_TYPE is empty"

describe "runtime_list_containers - when unavailable"

runtime_list_containers "" "" ""; result="$?"

assert_eq "1" "$result" "runtime_list_containers returns 1"

describe "runtime_list_images - when unavailable"

runtime_list_images "" "" ""; result="$?"

assert_eq "1" "$result" "runtime_list_images returns 1"

describe "runtime_require - when unavailable"

runtime_require "Section 5"; rc=$?

assert_return_code 1 $rc "runtime_require returns 1"

# --- Scenario B: docker binary exists but daemon unreachable ---

describe "runtime_discover - daemon unreachable"

cat > "$MOCK_DIR/docker" << 'MOCK'
#!/bin/bash
echo "Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?" >&2
exit 1
MOCK
chmod +x "$MOCK_DIR/docker"

# Re-source to reset globals
. "$SCRIPT_DIR/../../functions/runtime_lib.sh"

runtime_discover; rc=$?

assert_return_code 1 $rc "runtime_discover returns 1 when daemon unreachable"
assert_eq "unavailable" "$RUNTIME_STATUS" "RUNTIME_STATUS is 'unavailable'"
assert_eq "docker" "$RUNTIME_TYPE" "RUNTIME_TYPE is 'docker'"
assert_contains "$RUNTIME_ERROR" "cannot connect" "RUNTIME_ERROR mentions connection failure"

describe "runtime_list_containers - daemon unreachable"

runtime_list_containers "" "" ""; result="$?"

assert_eq "1" "$result" "runtime_list_containers returns 1"

describe "runtime_require - daemon unreachable"

runtime_require "Section 4"; rc=$?

assert_return_code 1 $rc "runtime_require returns 1"

test_summary
