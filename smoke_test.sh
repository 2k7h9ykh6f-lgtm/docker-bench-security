#!/bin/bash
# smoke.sh — Smoke tests for docker-bench-security
# Verifies that all scripts parse correctly and the CLI behaves as expected
# without requiring a running Docker daemon.

set -eo pipefail

SMOKE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SMOKE_DIR"

pass=0
fail=0
total=0

_smoke_pass() {
  total=$((total + 1))
  pass=$((pass + 1))
  printf "ok %d - %s\n" "$total" "$1"
}

_smoke_fail() {
  total=$((total + 1))
  fail=$((fail + 1))
  printf "not ok %d - %s\n" "$total" "$1"
  [ -n "${2:-}" ] && printf "    %s\n" "$2"
}

# ---------------------------------------------------------------------------
# 1. Syntax check: bash -n on all .sh files
# ---------------------------------------------------------------------------
printf "# Syntax check (bash -n)\n"

while IFS= read -r -d '' script; do
  rel_path="${script#"$REPO_ROOT"/}"
  if bash -n "$script" 2>/dev/null; then
    _smoke_pass "syntax: $rel_path"
  else
    err=$(bash -n "$script" 2>&1) || true
    _smoke_fail "syntax: $rel_path" "$err"
  fi
done < <(find "$REPO_ROOT" -name '*.sh' \
  -not -path '*/.git/*' \
  -not -path '*/tests/unit/*' \
  -print0 | sort -z)

# ---------------------------------------------------------------------------
# 2. Help output: -h should exit 0 and print usage
# ---------------------------------------------------------------------------
printf "\n# CLI help flag\n"

# We need to bypass the docker check. Create a fake docker that succeeds.
FAKE_BIN=$(mktemp -d)
cat > "$FAKE_BIN/docker" <<'FAKEDOCKER'
#!/bin/sh
if [ "$1" = "ps" ]; then
  echo "CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES"
  exit 0
fi
exit 0
FAKEDOCKER
chmod +x "$FAKE_BIN/docker"

help_output=""
help_rc=0
help_output=$(PATH="$FAKE_BIN:$PATH" bash "$REPO_ROOT/docker-bench-security.sh" -h 2>&1) || help_rc=$?

if [ "$help_rc" -eq 0 ]; then
  _smoke_pass "help: exits with code 0"
else
  _smoke_fail "help: exits with code 0" "got exit code $help_rc"
fi

if printf '%s' "$help_output" | grep -q "Usage:"; then
  _smoke_pass "help: output contains 'Usage:'"
else
  _smoke_fail "help: output contains 'Usage:'" "output did not match"
fi

if printf '%s' "$help_output" | grep -q "Docker Bench for Security"; then
  _smoke_pass "help: output contains project name"
else
  _smoke_fail "help: output contains project name" "output did not match"
fi

# ---------------------------------------------------------------------------
# 3. No-docker error path: script should fail gracefully
# ---------------------------------------------------------------------------
printf "\n# No-docker error path\n"

# Create a PATH with a docker that always fails
NO_DOCKER_BIN=$(mktemp -d)
cat > "$NO_DOCKER_BIN/docker" <<'FAILDOCKER'
#!/bin/sh
exit 1
FAILDOCKER
chmod +x "$NO_DOCKER_BIN/docker"

no_docker_output=""
no_docker_rc=0
no_docker_output=$(PATH="$NO_DOCKER_BIN:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin" bash "$REPO_ROOT/docker-bench-security.sh" 2>&1) || no_docker_rc=$?

if [ "$no_docker_rc" -ne 0 ]; then
  _smoke_pass "no-docker: exits non-zero"
else
  _smoke_fail "no-docker: exits non-zero" "got exit code $no_docker_rc"
fi

if printf '%s' "$no_docker_output" | grep -qi "error"; then
  _smoke_pass "no-docker: output contains error message"
else
  _smoke_fail "no-docker: output contains error message" "output: $no_docker_output"
fi

# ---------------------------------------------------------------------------
# 4. Specific check flag: -c with a nonexistent check should not crash
# ---------------------------------------------------------------------------
printf "\n# Check flag with bogus check name\n"

bogus_output=$(PATH="$FAKE_BIN:$PATH" bash "$REPO_ROOT/docker-bench-security.sh" -c check_nonexistent_999 2>&1) || true

if printf '%s' "$bogus_output" | grep -q "doesn't seem to exist"; then
  _smoke_pass "bogus-check: reports nonexistent check"
else
  _smoke_fail "bogus-check: reports nonexistent check" "output: $bogus_output"
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -rf "$FAKE_BIN" "$NO_DOCKER_BIN"
rm -rf "$REPO_ROOT/log"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n1..%d\n" "$total"
printf "# Smoke: %d tests, %d passed, %d failed\n" "$total" "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
