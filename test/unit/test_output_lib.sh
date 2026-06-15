#!/bin/bash
# Unit tests for functions/output_lib.sh
# Runs without Docker — exercises output/scoring functions with a temp logger.
set +u  # output_lib.sh uses uninitialized locals by design

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

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  TESTS=$((TESTS + 1))
  if echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label — expected to contain '$needle'"
  fi
}

# ── set up environment expected by output_lib.sh ───────────────────
TMPDIR_FIX="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIX"' EXIT

logger="$TMPDIR_FIX/test.log"
touch "$logger"
totalChecks=0
currentScore=0

# Source without color
nocolor="nocolor"
. "$REPO_ROOT/functions/output_lib.sh"

# ── color disable ──────────────────────────────────────────────────
echo "--- color disable ---"
assert_eq "bldred empty when nocolor" "" "$bldred"
assert_eq "bldgrn empty when nocolor" "" "$bldgrn"
assert_eq "bldblu empty when nocolor" "" "$bldblu"
assert_eq "txtrst empty when nocolor" "" "$txtrst"

# ── logit ──────────────────────────────────────────────────────────
echo "--- logit ---"
> "$logger"
logit "hello world"
assert_contains "logit writes to logger" "hello world" "$(cat "$logger")"

# ── pass ───────────────────────────────────────────────────────────
echo "--- pass ---"
> "$logger"
currentScore=0; totalChecks=0
pass "simple pass message"
assert_contains "pass simple: logger has PASS" "[PASS]" "$(cat "$logger")"

> "$logger"
currentScore=0; totalChecks=0
pass -s "scored pass"
assert_eq "pass -s: score incremented" "1" "$currentScore"
assert_eq "pass -s: checks incremented" "1" "$totalChecks"

> "$logger"
currentScore=0; totalChecks=0
pass -c "counted pass"
assert_eq "pass -c: score unchanged" "0" "$currentScore"
assert_eq "pass -c: checks incremented" "1" "$totalChecks"

# ── warn ───────────────────────────────────────────────────────────
echo "--- warn ---"
> "$logger"
currentScore=0; totalChecks=0
warn "simple warn"
assert_contains "warn simple: logger has WARN" "[WARN]" "$(cat "$logger")"

> "$logger"
currentScore=0; totalChecks=0
warn -s "scored warn"
assert_eq "warn -s: score decremented" "-1" "$currentScore"
assert_eq "warn -s: checks incremented" "1" "$totalChecks"

# ── info ───────────────────────────────────────────────────────────
echo "--- info ---"
> "$logger"
totalChecks=0
info "simple info"
assert_contains "info simple: logger has INFO" "[INFO]" "$(cat "$logger")"
assert_eq "info simple: checks unchanged" "0" "$totalChecks"

> "$logger"
totalChecks=0
info -c "counted info"
assert_eq "info -c: checks incremented" "1" "$totalChecks"

# ── note ───────────────────────────────────────────────────────────
echo "--- note ---"
> "$logger"
totalChecks=0
note "simple note"
assert_contains "note simple: logger has NOTE" "[NOTE]" "$(cat "$logger")"
assert_eq "note simple: checks unchanged" "0" "$totalChecks"

> "$logger"
totalChecks=0
note -c "counted note"
assert_eq "note -c: checks incremented" "1" "$totalChecks"

# ── summary ────────────────────────────────────────────────────────
echo ""
echo "test_output_lib: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
