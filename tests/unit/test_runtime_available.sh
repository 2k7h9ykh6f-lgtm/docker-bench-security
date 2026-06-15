#!/bin/bash
# --------------------------------------------------------------------------------------------
# Test: Runtime available (docker daemon responding normally with containers/images)
# --------------------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/test_framework.sh"

# Create a temporary directory with a mock docker binary
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

cat > "$MOCK_DIR/docker" << 'MOCK'
#!/bin/bash
case "$*" in
  "ps -q")
    echo "abc123"
    echo "def456"
    ;;
  "ps"|"ps "*)
    echo "CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES"
    echo "abc123def012   nginx   nginx     2 days    Up 2d            web-app"
    echo "def456abc789   redis   redis     1 day     Up 1d            cache"
    ;;
  "images -q"|"images -q "*)
    echo "aaa111bbb222"
    echo "ccc333ddd444"
    ;;
  "images"|"images "*)
    echo "REPOSITORY   TAG       IMAGE ID       CREATED       SIZE"
    echo "nginx        latest    aaa111bbb222   2 days ago    142MB"
    echo "redis        latest    ccc333ddd444   1 day ago     113MB"
    ;;
  "inspect"*)
    # Return empty labels (not the bench container)
    echo "map[]"
    ;;
  *)
    exit 0
    ;;
esac
MOCK
chmod +x "$MOCK_DIR/docker"

# Prepend mock to PATH so it takes precedence
export PATH="$MOCK_DIR:$PATH"

# Source the module under test
. "$SCRIPT_DIR/../../functions/runtime_lib.sh"

# --- Tests ---

describe "runtime_discover - docker daemon available"

runtime_discover
rc=$?

assert_return_code 0 $rc "runtime_discover returns 0"
assert_eq "available" "$RUNTIME_STATUS" "RUNTIME_STATUS is 'available'"
assert_eq "docker" "$RUNTIME_TYPE" "RUNTIME_TYPE is 'docker'"
assert_empty "$RUNTIME_ERROR" "RUNTIME_ERROR is empty"

describe "runtime_list_containers - with running containers"

result=$(runtime_list_containers "" "" "")
rc=$?

assert_return_code 0 $rc "runtime_list_containers returns 0"
assert_not_empty "$result" "container list is not empty"
assert_contains "$result" "web-app" "container list contains 'web-app'"
assert_contains "$result" "cache" "container list contains 'cache'"

describe "runtime_list_images - with images present"

result=$(runtime_list_images "" "" "")
rc=$?

assert_return_code 0 $rc "runtime_list_images returns 0"
assert_not_empty "$result" "image list is not empty"
assert_contains "$result" "aaa111bbb222" "image list contains nginx ID"
assert_contains "$result" "ccc333ddd444" "image list contains redis ID"

describe "runtime_require - when available"

runtime_require "Section 5"
rc=$?

assert_return_code 0 $rc "runtime_require returns 0 when available"

test_summary
