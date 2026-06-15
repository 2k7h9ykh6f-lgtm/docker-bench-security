#!/bin/bash
# --------------------------------------------------------------------------------------------
# Test: Runtime available but with empty container/image lists
#
# This validates the critical distinction: RUNTIME_STATUS="available" means the daemon
# is reachable, even if there are zero containers or images. This is different from
# "unavailable" where the daemon itself cannot be reached.
# --------------------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/test_framework.sh"

MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

cat > "$MOCK_DIR/docker" << 'MOCK'
#!/bin/bash
case "$*" in
  "ps -q")
    # No output = no containers
    ;;
  "ps"|"ps "*)
    # Header only, no containers
    echo "CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES"
    ;;
  "images -q"|"images -q "*)
    # Quiet mode: no output = no images
    ;;
  "images"|"images "*)
    # Header only, no images
    echo "REPOSITORY   TAG   IMAGE ID   CREATED   SIZE"
    ;;
  "inspect"*)
    echo "map[]"
    ;;
  *)
    exit 0
    ;;
esac
MOCK
chmod +x "$MOCK_DIR/docker"
export PATH="$MOCK_DIR:$PATH"

. "$SCRIPT_DIR/../../functions/runtime_lib.sh"

# --- Tests ---

describe "runtime_discover - empty runtime (daemon up, no containers)"

runtime_discover
rc=$?

assert_return_code 0 $rc "runtime_discover returns 0 (daemon is reachable)"
assert_eq "available" "$RUNTIME_STATUS" "RUNTIME_STATUS is 'available' even with no containers"
assert_eq "docker" "$RUNTIME_TYPE" "RUNTIME_TYPE is 'docker'"
assert_empty "$RUNTIME_ERROR" "RUNTIME_ERROR is empty"

describe "runtime_list_containers - empty list"

result=$(runtime_list_containers "" "" "")
rc=$?

assert_return_code 0 $rc "runtime_list_containers returns 0 (runtime works)"
assert_empty "$result" "container list is empty (no containers exist)"

describe "runtime_list_images - empty list"

result=$(runtime_list_images "" "" "")
rc=$?

assert_return_code 0 $rc "runtime_list_images returns 0 (runtime works)"
assert_empty "$result" "image list is empty (no images exist)"

describe "runtime_require - available but empty"

runtime_require "Section 5"
rc=$?

assert_return_code 0 $rc "runtime_require returns 0 (runtime is available, just empty)"

describe "distinction: available+empty vs unavailable"

# This is the key semantic test: when the daemon is up but has nothing,
# RUNTIME_STATUS="available" and runtime_require succeeds.
# When the daemon is down, RUNTIME_STATUS="unavailable" and runtime_require fails.
# The existing check guards (if [ -z "$containers" ]) handle both cases correctly:
# - available + empty containers: checks run but find nothing to iterate
# - unavailable + empty containers: section is skipped before checks run

assert_eq "available" "$RUNTIME_STATUS" "status correctly reflects daemon state, not data state"

runtime_require "Section 4"
rc=$?
assert_return_code 0 $rc "sections are NOT skipped when runtime is available (even if empty)"

test_summary
