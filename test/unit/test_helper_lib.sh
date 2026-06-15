#!/bin/bash
# Unit tests for functions/helper_lib.sh
# Runs without Docker — tests only pure/fixture-able functions.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ── minimal assertion harness ──────────────────────────────────────
TESTS=0; PASS=0; FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  TESTS=$((TESTS + 1))
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label — expected '$expected', got '$actual'"
  fi
}

assert_rc() {
  local label="$1" expected="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local rc=$?
  assert_eq "$label" "$expected" "$rc"
}

# ── source the library under test ──────────────────────────────────
. "$REPO_ROOT/functions/helper_lib.sh"

# ── abspath ────────────────────────────────────────────────────────
echo "--- abspath ---"
assert_eq "absolute stays absolute" "/usr/bin" "$(abspath /usr/bin)"
assert_eq "relative gets PWD prefix" "$PWD/foo" "$(abspath foo)"

# ── do_version_check ───────────────────────────────────────────────
echo "--- do_version_check ---"

do_version_check "1.2.3" "1.2.3"; assert_eq "equal versions" "10" "$?"
do_version_check "2.0.0" "1.0.0"; assert_eq "greater major" "11" "$?"
do_version_check "1.0.0" "2.0.0"; assert_eq "lesser major"  "9"  "$?"
do_version_check "1.3.0" "1.2.0"; assert_eq "greater minor" "11" "$?"
do_version_check "1.2.0" "1.3.0"; assert_eq "lesser minor"  "9"  "$?"
do_version_check "1.2.4" "1.2.3"; assert_eq "greater patch" "11" "$?"
do_version_check "1.2.3" "1.2.4"; assert_eq "lesser patch"  "9"  "$?"
do_version_check "20.10.17" "20.10.9"; assert_eq "docker-style greater" "11" "$?"
do_version_check "20.10.9" "20.10.17"; assert_eq "docker-style lesser"  "9"  "$?"

# ── get_docker_configuration_file_args (fixture) ───────────────────
echo "--- get_docker_configuration_file_args ---"

TMPDIR_FIX="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIX"' EXIT

cat > "$TMPDIR_FIX/daemon.json" <<'JSON'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "live-restore": true,
  "userland-proxy": false
}
JSON

# Override CONFIG_FILE so the function reads our fixture
CONFIG_FILE="$TMPDIR_FIX/daemon.json"

# Stub get_docker_configuration_file to be a no-op (we set CONFIG_FILE directly)
get_docker_configuration_file() { :; }

if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=true
  result=$(get_docker_configuration_file_args "storage-driver")
  assert_eq "jq: storage-driver" "overlay2" "$result"

  result=$(get_docker_configuration_file_args "live-restore")
  assert_eq "jq: live-restore (bool)" "true" "$result"

  result=$(get_docker_configuration_file_args "nonexistent")
  assert_eq "jq: missing key returns empty" "" "$result"
else
  echo "SKIP: jq not found — skipping jq-path tests"
fi

# grep/sed fallback path
HAVE_JQ=false
result=$(get_docker_configuration_file_args "storage-driver")
assert_eq "grep fallback: storage-driver" "overlay2" "$result"

# ── summary ────────────────────────────────────────────────────────
echo ""
echo "test_helper_lib: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
