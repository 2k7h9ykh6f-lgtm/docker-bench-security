#!/bin/bash
# test_runner.sh — Minimal TAP-like test runner for docker-bench-security
# No external dependencies (no bats, no shunit2). Pure bash.
#
# Usage: test_runner.sh [test_file.sh ...]
#   If no files are given, runs all tests/unit/test_*.sh

set -eo pipefail

# ---------------------------------------------------------------------------
# Assert helpers
# ---------------------------------------------------------------------------
_ASSERTIONS=0
_FAILURES=0

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  _ASSERTIONS=$((_ASSERTIONS + 1))
  if [ "$expected" = "$actual" ]; then
    return 0
  fi
  _FAILURES=$((_FAILURES + 1))
  printf "    ASSERT_EQ failed: expected '%s', got '%s'" "$expected" "$actual"
  [ -n "$msg" ] && printf "  (%s)" "$msg"
  printf "\n"
  return 1
}

assert_ne() {
  local unexpected="$1" actual="$2" msg="${3:-}"
  _ASSERTIONS=$((_ASSERTIONS + 1))
  if [ "$unexpected" != "$actual" ]; then
    return 0
  fi
  _FAILURES=$((_FAILURES + 1))
  printf "    ASSERT_NE failed: did not expect '%s'" "$unexpected"
  [ -n "$msg" ] && printf "  (%s)" "$msg"
  printf "\n"
  return 1
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  _ASSERTIONS=$((_ASSERTIONS + 1))
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    return 0
  fi
  _FAILURES=$((_FAILURES + 1))
  printf "    ASSERT_CONTAINS failed: '%s' not found in output" "$needle"
  [ -n "$msg" ] && printf "  (%s)" "$msg"
  printf "\n"
  return 1
}

assert_exit_code() {
  local expected="$1" actual="$2" msg="${3:-}"
  _ASSERTIONS=$((_ASSERTIONS + 1))
  if [ "$expected" = "$actual" ]; then
    return 0
  fi
  _FAILURES=$((_FAILURES + 1))
  printf "    ASSERT_EXIT_CODE failed: expected %s, got %s" "$expected" "$actual"
  [ -n "$msg" ] && printf "  (%s)" "$msg"
  printf "\n"
  return 1
}

export -f assert_eq assert_ne assert_contains assert_exit_code

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$RUNNER_DIR/../.." && pwd)"
export REPO_ROOT

# Collect test files
test_files=()
if [ $# -gt 0 ]; then
  test_files=("$@")
else
  for f in "$RUNNER_DIR"/test_*.sh; do
    [ -f "$f" ] && [ "$(basename "$f")" != "test_runner.sh" ] && test_files+=("$f")
  done
fi

if [ ${#test_files[@]} -eq 0 ]; then
  echo "No test files found."
  exit 0
fi

total_tests=0
total_pass=0
total_fail=0
all_failures=""

for test_file in "${test_files[@]}"; do
  test_name="$(basename "$test_file" .sh)"
  printf "# %s\n" "$test_name"

  # Run entire file in a subshell to isolate function definitions
  file_result=$(
    REPO_ROOT="$REPO_ROOT"
    # shellcheck disable=SC1090
    source "$test_file"

    file_tests=0
    file_pass=0
    file_fail=0
    file_failures=""

    while IFS= read -r func; do
      file_tests=$((file_tests + 1))

      test_output=""
      test_rc=0
      test_output=$(
        # Re-source for fresh variable state inside subshell
        # shellcheck disable=SC1090
        source "$test_file" 2>/dev/null
        "$func" 2>&1
      ) || test_rc=$?

      if [ "$test_rc" -eq 0 ]; then
        file_pass=$((file_pass + 1))
        printf "ok - %s\n" "$func"
      else
        file_fail=$((file_fail + 1))
        printf "not ok - %s\n" "$func"
        if [ -n "$test_output" ]; then
          printf "%s\n" "$test_output" | sed 's/^/    /'
        fi
        file_failures="${file_failures}  ${func}\n"
      fi
    done < <(declare -F | awk '{print $3}' | grep '^test_' | sort)

    printf "# %s: %d/%d passed\n" "$test_name" "$file_pass" "$file_tests"
    # Emit machine-readable summary line
    printf "SUMMARY %d %d %d\n" "$file_tests" "$file_pass" "$file_fail"
    if [ -n "$file_failures" ]; then
      printf "FAILURES\n%b" "$file_failures"
    fi
  )

  # Parse subshell output for summary
  file_summary=$(printf '%s\n' "$file_result" | grep '^SUMMARY ' | head -1)
  ft=$(echo "$file_summary" | awk '{print $2}')
  fp=$(echo "$file_summary" | awk '{print $3}')
  ff=$(echo "$file_summary" | awk '{print $4}')

  # Print test results (non-SUMMARY/FAILURES lines), renumbering globally
  while IFS= read -r line; do
    case "$line" in
      SUMMARY*|FAILURES) continue ;;
      "  "*) continue ;;
      "ok - "*)
        total_tests=$((total_tests + 1))
        total_pass=$((total_pass + 1))
        fname="${line#ok - }"
        printf "ok %d - %s\n" "$total_tests" "$fname"
        ;;
      "not ok - "*)
        total_tests=$((total_tests + 1))
        total_fail=$((total_fail + 1))
        fname="${line#not ok - }"
        printf "not ok %d - %s\n" "$total_tests" "$fname"
        all_failures="${all_failures}  ${test_name}::${fname}\n"
        ;;
      *) printf "%s\n" "$line" ;;
    esac
  done <<< "$file_result"

  printf "\n"
done

# Summary
printf "1..%d\n" "$total_tests"
printf "# Total: %d tests, %d passed, %d failed\n" "$total_tests" "$total_pass" "$total_fail"

if [ "$total_fail" -gt 0 ]; then
  printf "# Failed:\n"
  printf "%b" "$all_failures"
  exit 1
fi

exit 0
