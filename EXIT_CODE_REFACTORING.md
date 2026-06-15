# Exit Code Strategy Refactoring

## Summary

This refactoring implements configurable exit code strategies for Docker Bench Security, making it CI-friendly while maintaining backward compatibility.

## Changes

### 1. Enhanced Counter Tracking (`functions/output_lib.sh`)

Added individual counters for each result type:
- `passCount` - Number of PASS results (scored and counted)
- `warnCount` - Number of WARN results (scored only)
- `infoCount` - Number of INFO results (counted only)
- `noteCount` - Number of NOTE results (counted only)

These counters are incremented alongside the existing `totalChecks` counter in their respective output functions.

### 2. Exit Code Computation (`functions/helper_lib.sh`)

Added `compute_exit_code()` function that implements four exit strategies:

#### Strategy: `none` (default)
- **Exit code**: Always 0
- **Use case**: Backward compatibility, manual runs
- **Behavior**: Script always exits successfully regardless of results

#### Strategy: `warn`
- **Exit codes**: 0 (no warnings) or 1 (warnings present)
- **Use case**: Basic CI gating
- **Behavior**:
  - Exit 0 if `warnCount == 0`
  - Exit 1 if `warnCount > 0`
- **Example**: `./docker-bench-security.sh -X warn`

#### Strategy: `info`
- **Exit codes**: 0 (clean), 1 (info only), or 2 (warnings present)
- **Use case**: Strict CI mode
- **Behavior**:
  - Exit 0 if `warnCount == 0 && infoCount == 0`
  - Exit 1 if `warnCount == 0 && infoCount > 0`
  - Exit 2 if `warnCount > 0`
- **Example**: `./docker-bench-security.sh -X info`

#### Strategy: `score`
- **Exit codes**: 0 (score >= threshold) or 1 (score < threshold)
- **Use case**: Score-based quality gates
- **Behavior**:
  - Exit 0 if `currentScore >= threshold`
  - Exit 1 if `currentScore < threshold`
- **Example**: `./docker-bench-security.sh -X score -S -5` (fail if score < -5)

### 3. CLI Flags (`docker-bench-security.sh`)

Added two new command-line options:

- `-X STRATEGY` - Set exit code strategy (none|warn|info|score)
- `-S THRESHOLD` - Set score threshold for score strategy (default: 0)

### 4. Enhanced Summary Report

The final summary now displays detailed breakdown:

```
Section C - Score

Checks: 42
Score: 35
PASS: 38 | WARN: 3 | INFO: 1 | NOTE: 0
```

### 5. JSON Output Enhancement

The JSON output now includes individual counts:

```json
{
  "checks": 42,
  "score": 35,
  "pass": 38,
  "warn": 3,
  "info": 1,
  "note": 0,
  "end": 1234567890
}
```

## Usage Examples

### Default (backward compatible)
```bash
./docker-bench-security.sh
# Always exits 0
```

### CI with WARN gate
```bash
./docker-bench-security.sh -X warn
# Exit 1 if any WARN found, else 0
```

### Strict CI mode
```bash
./docker-bench-security.sh -X info
# Exit 2 if WARN, exit 1 if INFO, else 0
```

### Score-based gate
```bash
./docker-bench-security.sh -X score -S 0
# Exit 1 if score < 0, else 0

./docker-bench-security.sh -X score -S -10
# Exit 1 if score < -10, else 0
```

## Test Coverage

Created comprehensive test suite in `tests/unit/`:

### Test 1: Exit Code Strategies (`test_exit_code.sh`)
- 21 test cases covering all four strategies
- Tests edge cases: zero values, negative scores, custom thresholds
- Validates unknown strategy fallback

### Test 2: Output Counters (`test_output_counters.sh`)
- 19 test cases for counter incrementation
- Tests `pass -s`, `pass -c`, `warn -s`, `info -c`, `note -c`
- Validates counter accumulation across multiple operations

### Running Tests
```bash
# Run all tests
sh tests/unit/run_all_tests.sh

# Run individual test suites
sh tests/unit/test_exit_code.sh
sh tests/unit/test_output_counters.sh
```

## CI Integration Examples

### GitHub Actions
```yaml
- name: Docker Security Scan
  run: ./docker-bench-security.sh -X warn
  # Job fails if any WARN found
```

### GitLab CI
```yaml
docker-security:
  script:
    - ./docker-bench-security.sh -X score -S 0
  allow_failure: false
  # Pipeline fails if score < 0
```

### Jenkins
```groovy
stage('Security Scan') {
    steps {
        sh './docker-bench-security.sh -X info'
        // Build fails if WARN (exit 2) or INFO (exit 1)
    }
}
```

## Backward Compatibility

- Default behavior unchanged: exit code is always 0 unless `-X` flag is used
- Existing scripts and workflows continue to work without modification
- New flags are optional and only affect exit code, not check execution

## Implementation Details

### Exit Code Flow
1. All checks execute normally, updating counters
2. Summary report displays results
3. `compute_exit_code()` evaluates strategy against counters
4. Function returns appropriate exit code via `return` statement
5. Main script captures return code and calls `exit $exitCode`

### Counter Scope
- Counters are global variables initialized in main script
- Output functions (`pass`, `warn`, `info`, `note`) increment counters
- Counters persist throughout script execution
- Final values used for both summary display and exit code computation

### Error Handling
- Unknown strategy values trigger warning to stderr
- Unknown strategies fall back to `none` (exit 0)
- Invalid threshold values handled by shell arithmetic (default to 0)
