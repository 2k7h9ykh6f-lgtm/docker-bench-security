#!/bin/bash
# --------------------------------------------------------------------------------------------
# Test: Runtime permission denied (user lacks access to docker socket)
# --------------------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/test_framework.sh"

MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

# --- Scenario A: Exit code 126 (cannot execute / permission denied by shell) ---

describe "runtime_discover - permission denied (exit 126)"

cat > "$MOCK_DIR/docker" << 'MOCK'
#!/bin/bash
echo "docker: permission denied while trying to connect to the Docker daemon socket" >&2
exit 126
MOCK
chmod +x "$MOCK_DIR/docker"
export PATH="$MOCK_DIR:$PATH"

. "$SCRIPT_DIR/../../functions/runtime_lib.sh"

runtime_discover; rc=$?

assert_return_code 2 $rc "runtime_discover returns 2 for permission denied"
assert_eq "permission_denied" "$RUNTIME_STATUS" "RUNTIME_STATUS is 'permission_denied'"
assert_eq "docker" "$RUNTIME_TYPE" "RUNTIME_TYPE is 'docker'"
assert_not_empty "$RUNTIME_ERROR" "RUNTIME_ERROR is not empty"

describe "runtime_list_containers - permission denied"

runtime_list_containers "" "" ""; result="$?"

assert_eq "1" "$result" "runtime_list_containers returns 1"

describe "runtime_require - permission denied"

runtime_require "Section 5"; rc=$?

assert_return_code 1 $rc "runtime_require returns 1"

# --- Scenario B: Exit code 1 with "permission denied" in stderr ---

describe "runtime_discover - permission denied (stderr keyword)"

cat > "$MOCK_DIR/docker" << 'MOCK'
#!/bin/bash
echo "Got permission denied while trying to connect to the Docker daemon socket at /var/run/docker.sock" >&2
exit 1
MOCK
chmod +x "$MOCK_DIR/docker"

# Re-source to reset globals
. "$SCRIPT_DIR/../../functions/runtime_lib.sh"

runtime_discover; rc=$?

assert_return_code 2 $rc "runtime_discover returns 2 for permission denied in stderr"
assert_eq "permission_denied" "$RUNTIME_STATUS" "RUNTIME_STATUS is 'permission_denied'"

# --- Scenario C: Exit code 1 with "access denied" in stderr ---

describe "runtime_discover - access denied (stderr keyword)"

cat > "$MOCK_DIR/docker" << 'MOCK'
#!/bin/bash
echo "access denied: user not in docker group" >&2
exit 1
MOCK
chmod +x "$MOCK_DIR/docker"

# Re-source to reset globals
. "$SCRIPT_DIR/../../functions/runtime_lib.sh"

runtime_discover; rc=$?

assert_return_code 2 $rc "runtime_discover returns 2 for access denied in stderr"
assert_eq "permission_denied" "$RUNTIME_STATUS" "RUNTIME_STATUS is 'permission_denied'"

describe "runtime_list_images - permission denied"

runtime_list_images "" "" ""; result="$?"

assert_eq "1" "$result" "runtime_list_images returns 1"

test_summary
