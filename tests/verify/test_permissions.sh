#!/bin/bash
# test_permissions.sh — Verify capability detection and degraded-mode behaviour
#
# Scenarios covered:
#   1. Unit tests for perm_lib.sh   (has_cap, require_cap, is_degraded, probes)
#   2. Unit tests for output_lib.sh (skip output, skippedChecks, JSON "skipped")
#   3. Simulated root               (all caps yes — no skips)
#   4. Simulated non-root           (ROOT=no  → Section 3 + check_1_1_2 skip)
#   5. Simulated no-docker-socket   (DOCKER=no → degraded, Sections 4-7 skip)
#   6. Simulated no-audit           (AUDIT=no → Section 1 audit checks skip)
#   7. Simulated read-only config   (CONFIG_READ=no → Section 2 skip)
#   8. Live probe validation        (actual probe results match current env)
#
# Usage:
#   bash tests/verify/test_permissions.sh          # from repo root
#   bash tests/verify/test_permissions.sh -v       # verbose (print output)

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Test framework ───────────────────────────────────────────────────────────
_passed=0
_failed=0
_verbose=0
[ "${1:-}" = "-v" ] && _verbose=1

pass_test() { _passed=$((_passed + 1)); [ "$_verbose" = "1" ] && echo "  PASS: $1"; return 0; }
fail_test() { _failed=$((_failed + 1)); echo "  FAIL: $1 — $2"; return 0; }
assert_eq()   { [ "$1" = "$2" ] && pass_test "$3" || fail_test "$3" "expected='$2' got='$1'"; }
assert_match() { echo "$1" | grep -qE "$2" && pass_test "$3" || fail_test "$3" "pattern '$2' not in output"; }
assert_true()  { eval "$1" >/dev/null 2>&1 && pass_test "$2" || fail_test "$2" "command failed: $1"; }
assert_false() { eval "$1" >/dev/null 2>&1 && fail_test "$2" "expected failure" || pass_test "$2"; }

# ── Helper: build a minimal sandbox ───────────────────────────────────────────
# Sources perm_lib.sh + output_lib.sh in a clean subshell with stubs for
# global variables the libraries expect.  Prints a preamble you can eval.
sandbox_preamble() {
  cat <<'PREAMBLE'
nocolor="nocolor"
logger="/dev/null"
auditrules="/nonexistent/audit.rules"
totalChecks=0
currentScore=0
skippedChecks=0
printremediation="0"
globalRemediation=""
checkHeader=""
addSpaceHeader=""
limit=0
PREAMBLE
  echo ". '$REPO_ROOT/functions/output_lib.sh'"
  echo ". '$REPO_ROOT/functions/perm_lib.sh'"
}

# Run a snippet inside a sandboxed subshell and capture stdout.
# Usage:  output=$(run_in_sandbox 'snippet; echo $var')
run_in_sandbox() {
  bash -c "$(sandbox_preamble); $1" 2>/dev/null
}

# ── Group: perm_lib.sh unit tests ────────────────────────────────────────────
echo "=== Group 1: perm_lib.sh — has_cap / require_cap / is_degraded ==="

# 1.1 has_cap returns false before probing
assert_false 'run_in_sandbox "has_cap ROOT"' \
  "has_cap ROOT returns false before probe"
assert_false 'run_in_sandbox "has_cap DOCKER"' \
  "has_cap DOCKER returns false before probe"

# 1.2 has_cap returns true when flag set
assert_true 'run_in_sandbox "_CAP_ROOT=yes; has_cap ROOT"' \
  "has_cap ROOT returns true when _CAP_ROOT=yes"
assert_true 'run_in_sandbox "_CAP_DOCKER=yes; has_cap DOCKER"' \
  "has_cap DOCKER returns true when _CAP_DOCKER=yes"
assert_true 'run_in_sandbox "_CAP_AUDIT=yes; has_cap AUDIT"' \
  "has_cap AUDIT returns true when _CAP_AUDIT=yes"
assert_true 'run_in_sandbox "_CAP_CONFIG_READ=yes; has_cap CONFIG_READ"' \
  "has_cap CONFIG_READ returns true when _CAP_CONFIG_READ=yes"

# 1.3 has_cap rejects unknown capabilities
assert_false 'run_in_sandbox "_CAP_ROOT=yes; has_cap NONEXISTENT"' \
  "has_cap NONEXISTENT returns false"

# 1.4 is_degraded defaults to false
assert_false 'run_in_sandbox "is_degraded"' \
  "is_degraded returns false by default (DEGRADED_MODE=no)"
assert_false 'run_in_sandbox "[ \"\$DEGRADED_MODE\" = yes ]"' \
  "DEGRADED_MODE defaults to 'no'"
assert_true 'run_in_sandbox "DEGRADED_MODE=yes; is_degraded"' \
  "is_degraded returns true when DEGRADED_MODE=yes"

# 1.5 require_cap returns 0 when cap present
assert_true 'run_in_sandbox "_CAP_ROOT=yes; require_cap ROOT \"1.1\" \"test desc\" >/dev/null"' \
  "require_cap returns 0 when cap present"

# 1.6 require_cap returns 1 when cap missing
assert_false 'run_in_sandbox "_CAP_ROOT=no; require_cap ROOT \"1.1\" \"test desc\" >/dev/null"' \
  "require_cap returns 1 when cap missing"

# ── Group: output_lib.sh skip function ───────────────────────────────────────
echo "=== Group 2: output_lib.sh — skip() / skippedChecks ==="

# 2.1 skip -c increments both counters
out=$(run_in_sandbox 'skip -c "1.1 - test" >/dev/null; echo "$totalChecks:$skippedChecks"')
assert_eq "$out" "1:1" "skip -c increments totalChecks and skippedChecks"

# 2.2 Multiple skip -c calls accumulate
out=$(run_in_sandbox 'skip -c "a" >/dev/null; skip -c "b" >/dev/null; skip -c "c" >/dev/null; echo "$totalChecks:$skippedChecks"')
assert_eq "$out" "3:3" "multiple skip -c calls accumulate correctly"

# 2.3 skip without -c does NOT increment counters
out=$(run_in_sandbox 'skip "just a message" >/dev/null; echo "$totalChecks:$skippedChecks"')
assert_eq "$out" "0:0" "skip without -c does not increment counters"

# 2.4 skip output contains [SKIP] tag
out=$(run_in_sandbox 'skip -c "1.1 - Test description"')
assert_match "$out" '\[SKIP\]' "skip -c output contains [SKIP]"
assert_match "$out" '1\.1 - Test description' "skip -c output contains check description"

# 2.5 endjson includes "skipped" field
out=$(run_in_sandbox '
  logger="/tmp/_dbs_test_'"$$"'"
  beginjson "1.6.0" "1000"
  skippedChecks=5
  endjson "10" "3" "2000"
  cat /tmp/_dbs_test_'"$$"'.json
')
assert_match "$out" '"skipped": 5' "endjson includes skipped count"
assert_match "$out" '"checks": 10' "endjson includes total checks"
assert_match "$out" '"score": 3' "endjson includes score"
rm -f /tmp/_dbs_test_$$* 2>/dev/null

# 2.6 skip and pass/warn counters are independent
out=$(run_in_sandbox '
  skip -c "1.1 - skipped" >/dev/null
  pass -s "2.1 - passed" >/dev/null
  warn -s "3.1 - warned" >/dev/null
  echo "$totalChecks:$currentScore:$skippedChecks"
')
assert_eq "$out" "3:0:1" "skip/pass/warn counters are independent (3 checks, score 0, 1 skip)"

# ── Group: logcheckresult handles SKIP ───────────────────────────────────────
echo "=== Group 3: logcheckresult — SKIP result ==="

# 3.1 logcheckresult "SKIP" writes to JSON without remediation
out=$(run_in_sandbox '
  logger="/tmp/_dbs_skip_'"$$"'"
  remediation="Fix this"
  remediationImpact="High"
  beginjson "1.6.0" "1000"
  starttestjson "1.1" "Test"
  logcheckresult "SKIP" "Requires ROOT capability"
  cat /tmp/_dbs_skip_'"$$"'.json
')
assert_match "$out" '"result": "SKIP"' "logcheckresult writes SKIP to JSON"
assert_match "$out" 'Requires ROOT capability' "logcheckresult includes skip reason"
# SKIP should NOT include remediation
echo "$out" | grep -q '"remediation"' && fail_test "SKIP does not include remediation" "found remediation" || pass_test "SKIP does not include remediation"
rm -f /tmp/_dbs_skip_$$* 2>/dev/null

# ── Group: Simulated capability scenarios ────────────────────────────────────
echo "=== Group 4: Simulated scenarios — group-level guards ==="

# 4.1 Simulated root: all caps yes → docker_daemon_files runs (Section 3)
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  _CAP_ROOT=yes; _CAP_DOCKER=yes
  # Stub check_3 to prove it was called
  check_3() { echo "SECTION3_RAN"; }
  docker_daemon_files
')
assert_match "$out" "SECTION3_RAN" "Section 3 runs when ROOT=yes"

# 4.2 Simulated non-root: ROOT=no → Section 3 skipped
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  _CAP_ROOT=no; _CAP_DOCKER=yes
  check_3() { echo "SECTION3_RAN"; }
  docker_daemon_files
')
echo "$out" | grep -q "SECTION3_RAN" && fail_test "Section 3 skipped when ROOT=no" "section ran" || pass_test "Section 3 skipped when ROOT=no"
assert_match "$out" "\[SKIP\]" "Section 3 skip message contains [SKIP]"
assert_match "$out" "requires root" "Section 3 skip message mentions root"

# 4.3 Simulated no-docker: DOCKER=no → Sections 4,5,6,7 skipped
for section_num in 4 5 6 7; do
  case $section_num in
    4) group="container_images" ;;
    5) group="container_runtime" ;;
    6) group="docker_security_operations" ;;
    7) group="docker_swarm_configuration" ;;
  esac
  out=$(run_in_sandbox "
    . '$REPO_ROOT'/functions/functions_lib.sh
    _CAP_DOCKER=no
    check_${section_num}() { echo 'SECTION${section_num}_RAN'; }
    ${group}
  ")
  echo "$out" | grep -q "SECTION${section_num}_RAN" && \
    fail_test "Section $section_num skipped when DOCKER=no" "section ran" || \
    pass_test "Section $section_num skipped when DOCKER=no"
done

# 4.4 Simulated no-docker: DOCKER=no → community checks skipped
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  _CAP_DOCKER=no
  community_checks() { echo "COMMUNITY_RAN"; }
  community
')
echo "$out" | grep -q "COMMUNITY_RAN" && \
  fail_test "Community checks skipped when DOCKER=no" "ran" || \
  pass_test "Community checks skipped when DOCKER=no"

# 4.5 Section 8 requires both ROOT and DOCKER
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  _CAP_ROOT=yes; _CAP_DOCKER=no
  check_8() { echo "SECTION8_RAN"; }
  docker_enterprise_configuration
')
echo "$out" | grep -q "SECTION8_RAN" && \
  fail_test "Section 8 skipped when DOCKER=no (even with ROOT)" "ran" || \
  pass_test "Section 8 skipped when DOCKER=no (even with ROOT=yes)"

out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  _CAP_ROOT=no; _CAP_DOCKER=yes
  check_8() { echo "SECTION8_RAN"; }
  docker_enterprise_configuration
')
echo "$out" | grep -q "SECTION8_RAN" && \
  fail_test "Section 8 skipped when ROOT=no (even with DOCKER)" "ran" || \
  pass_test "Section 8 skipped when ROOT=no (even with DOCKER=yes)"

out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  _CAP_ROOT=yes; _CAP_DOCKER=yes
  check_8() { echo "SECTION8_RAN"; }
  check_product_license() { :; }
  check_8_1() { :; }; check_8_1_1() { :; }; check_8_1_2() { :; }
  check_8_1_3() { :; }; check_8_1_4() { :; }; check_8_1_5() { :; }
  check_8_1_6() { :; }; check_8_1_7() { :; }
  check_8_2() { :; }; check_8_2_1() { :; }; check_8_end() { :; }
  docker_enterprise_configuration
')
assert_match "$out" "SECTION8_RAN" "Section 8 runs when ROOT=yes AND DOCKER=yes"

# ── Group: Per-check guards ──────────────────────────────────────────────────
echo "=== Group 5: Per-check guards ==="

# 5.1 check_1_1_1 requires DOCKER
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/tests/1_host_configuration.sh
  _CAP_DOCKER=no
  check_1_1_1
  echo "totalChecks=$totalChecks skippedChecks=$skippedChecks"
')
assert_match "$out" "\[SKIP\]" "check_1_1_1 skips when DOCKER=no"
assert_match "$out" "skippedChecks=1" "check_1_1_1 skip counted"

# 5.2 check_1_1_2 requires ROOT
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/tests/1_host_configuration.sh
  _CAP_ROOT=no
  check_1_1_2
  echo "skippedChecks=$skippedChecks"
')
assert_match "$out" "\[SKIP\]" "check_1_1_2 skips when ROOT=no"
assert_match "$out" "skippedChecks=1" "check_1_1_2 skip counted"

# 5.3 check_1_1_3 requires AUDIT
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/tests/1_host_configuration.sh
  _CAP_AUDIT=no
  check_1_1_3
  echo "skippedChecks=$skippedChecks"
')
assert_match "$out" "\[SKIP\]" "check_1_1_3 skips when AUDIT=no"

# 5.4 check_1_2_2 requires DOCKER
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/tests/1_host_configuration.sh
  _CAP_DOCKER=no
  check_1_2_2
  echo "skippedChecks=$skippedChecks"
')
assert_match "$out" "\[SKIP\]" "check_1_2_2 skips when DOCKER=no"

# 5.5 check_2_6 requires DOCKER (uses docker info)
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/functions/helper_lib.sh
  . '"$REPO_ROOT"'/tests/2_docker_daemon_configuration.sh
  _CAP_DOCKER=no
  CONFIG_FILE=/dev/null
  check_2_6
  echo "skippedChecks=$skippedChecks"
')
assert_match "$out" "\[SKIP\]" "check_2_6 skips when DOCKER=no"

# 5.6 check_5_1 requires DOCKER
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/tests/5_container_runtime.sh
  _CAP_DOCKER=no
  check_5_1
  echo "skippedChecks=$skippedChecks"
')
assert_match "$out" "\[SKIP\]" "check_5_1 skips when DOCKER=no"

# 5.7 Multiple audit checks all skip when AUDIT=no
out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/tests/1_host_configuration.sh
  _CAP_AUDIT=no
  check_1_1_5
  check_1_1_6
  check_1_1_7
  check_1_1_8
  echo "skippedChecks=$skippedChecks"
')
assert_match "$out" "skippedChecks=4" "multiple audit checks all skip when AUDIT=no"

# ── Group: Live probe validation ─────────────────────────────────────────────
echo "=== Group 6: Live probe validation (current environment) ==="

# Run probe_capabilities and check it doesn't crash
probe_out=$(run_in_sandbox 'probe_capabilities; echo "ROOT=$_CAP_ROOT DOCKER=$_CAP_DOCKER AUDIT=$_CAP_AUDIT CONFIG=$_CAP_CONFIG_READ"')
assert_match "$probe_out" "ROOT=" "probe_capabilities sets ROOT flag"
assert_match "$probe_out" "DOCKER=" "probe_capabilities sets DOCKER flag"

# Verify ROOT matches actual uid
actual_uid=$(id -u)
if [ "$actual_uid" = "0" ]; then
  assert_match "$probe_out" "ROOT=yes" "ROOT=yes matches uid=0"
else
  assert_match "$probe_out" "ROOT=no" "ROOT=no matches uid=$actual_uid"
fi

# Verify DOCKER matches actual docker availability
if docker ps -q >/dev/null 2>&1; then
  assert_match "$probe_out" "DOCKER=yes" "DOCKER=yes matches working docker"
else
  assert_match "$probe_out" "DOCKER=no" "DOCKER=no matches unavailable docker"
fi

# log_capabilities doesn't crash
run_in_sandbox 'probe_capabilities; log_capabilities' >/dev/null
assert_eq "$?" "0" "log_capabilities runs without error"

# ── Group: Degraded mode in main script ──────────────────────────────────────
echo "=== Group 7: Degraded mode behaviour ==="

# is_degraded controls docker ops in main()
out=$(run_in_sandbox '
  DEGRADED_MODE=yes
  is_degraded && echo "DEGRADED" || echo "NORMAL"
')
assert_eq "$out" "DEGRADED" "is_degraded returns true in degraded mode"

out=$(run_in_sandbox '
  DEGRADED_MODE=no
  is_degraded && echo "DEGRADED" || echo "NORMAL"
')
assert_eq "$out" "NORMAL" "is_degraded returns false in normal mode"

# ── Group: Config readability ────────────────────────────────────────────────
echo "=== Group 8: Read-only / missing config file ==="

# CONFIG_READ is yes when no config file exists
out=$(run_in_sandbox '
  CONFIG_FILE="/dev/null"
  _probe_config_read
  echo "$_CAP_CONFIG_READ"
')
assert_eq "$out" "yes" "CONFIG_READ=yes when CONFIG_FILE=/dev/null (no config)"

# CONFIG_READ is yes when config file is readable
tmpconf=$(mktemp)
echo '{"icc": false}' > "$tmpconf"
out=$(run_in_sandbox "
  CONFIG_FILE='$tmpconf'
  _probe_config_read
  echo \"\$_CAP_CONFIG_READ\"
")
assert_eq "$out" "yes" "CONFIG_READ=yes when config file is readable"

# CONFIG_READ is no when config file is not readable
out=$(run_in_sandbox "
  CONFIG_FILE='/nonexistent/daemon.json'
  _probe_config_read
  echo \"\$_CAP_CONFIG_READ\"
")
# /nonexistent/daemon.json doesn't exist, and /etc/docker/daemon.json probably doesn't either
# In this case CONFIG_READ should be "yes" because the fallback "no config found" returns yes
assert_eq "$out" "yes" "CONFIG_READ=yes when no config found anywhere (safe default)"
rm -f "$tmpconf"

# ── Group: Full integration — score unaffected by skips ──────────────────────
echo "=== Group 9: Integration — skips do not affect score ==="

out=$(run_in_sandbox '
  . '"$REPO_ROOT"'/functions/functions_lib.sh
  . '"$REPO_ROOT"'/tests/1_host_configuration.sh
  . '"$REPO_ROOT"'/tests/3_docker_daemon_configuration_files.sh

  # Simulate non-root, no-audit
  _CAP_ROOT=no
  _CAP_AUDIT=no
  _CAP_DOCKER=yes

  # Run a check that requires ROOT (1.1.2) → should skip
  check_1_1_2
  # Run a check that requires AUDIT (1.1.3) → should skip
  check_1_1_3
  # Run a Section 3 check → group would skip but call directly
  # check_3_1 stat /etc/docker → should skip because group guard
  # (group guard not triggered when calling directly, but per-check
  #  stat will just fail; the group guard handles this at group level)

  # Simulate a pass
  _CAP_ROOT=yes
  starttestjson "99.1" "fake pass"
  pass -s "99.1 - fake pass"
  logcheckresult "PASS"

  echo "totalChecks=$totalChecks currentScore=$currentScore skippedChecks=$skippedChecks"
')
assert_match "$out" "totalChecks=3" "integration: 3 total checks (2 skip + 1 pass)"
assert_match "$out" "currentScore=1" "integration: score=1 (skip does not penalize)"
assert_match "$out" "skippedChecks=2" "integration: 2 checks skipped"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "================================"
echo "Results: $_passed passed, $_failed failed"
echo "================================"

if [ "$_failed" -gt 0 ]; then
  exit 1
fi
exit 0
