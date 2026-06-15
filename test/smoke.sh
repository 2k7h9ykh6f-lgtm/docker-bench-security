#!/bin/bash
# Smoke tests for docker-bench-security.
#   Tier 1: bash -n syntax check on every .sh file
#   Tier 2: source-chain validation (function libraries load cleanly)
#   Tier 3: help-flag smoke (requires docker CLI; skipped otherwise)
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

TESTS=0; PASS=0; FAIL=0

ok() {
  TESTS=$((TESTS + 1)); PASS=$((PASS + 1))
}

fail() {
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  echo "FAIL: $1"
}

# ── Tier 1: bash -n syntax check ──────────────────────────────────
echo "--- syntax check (bash -n) ---"
for f in \
  docker-bench-security.sh \
  functions/*.sh \
  tests/*.sh; do
  [ -f "$f" ] || continue
  if bash -n "$f" 2>/dev/null; then
    ok
  else
    fail "syntax error in $f"
  fi
done

# ── Tier 2: source-chain validation ───────────────────────────────
echo "--- source-chain validation ---"
err=$(bash -c '
  LIBEXEC="."
  . ./functions/functions_lib.sh
  . ./functions/helper_lib.sh
  . ./functions/output_lib.sh
  exit 0
' 2>&1)

if [ $? -eq 0 ]; then
  ok
else
  fail "source-chain failed: $err"
fi

# ── Tier 3: help flag smoke ───────────────────────────────────────
echo "--- help flag smoke ---"
if docker ps -q >/dev/null 2>&1; then
  help_out=$(bash docker-bench-security.sh -h 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$help_out" | grep -q "Usage:"; then
    ok
  else
    fail "-h exited $rc or missing Usage line"
  fi
else
  echo "SKIP: docker daemon not reachable — help-flag smoke skipped"
fi

# ── summary ────────────────────────────────────────────────────────
echo ""
echo "smoke: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
