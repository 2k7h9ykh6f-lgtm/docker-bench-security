# Makefile for docker-bench-security test harness
#
# Targets:
#   make lint       — Run shellcheck on all project shell scripts
#   make test-unit  — Run unit tests (helper_lib, output_lib)
#   make test-smoke — Run smoke tests (syntax, CLI, error paths)
#   make test       — Run all: lint + test-unit + test-smoke
#   make clean      — Remove generated log files

SHELL := /bin/bash

# All project shell scripts (exclude .git and our test runner infra)
SCRIPTS := $(shell find . -name '*.sh' \
	-not -path './.git/*' \
	-not -path './tests/unit/*' \
	| sort)

.PHONY: all lint test-unit test-smoke test clean help

all: test

help:
	@echo "Targets:"
	@echo "  lint        Run shellcheck on all shell scripts"
	@echo "  test-unit   Run unit tests for helper_lib and output_lib"
	@echo "  test-smoke  Run smoke tests (syntax, CLI, error paths)"
	@echo "  test        Run lint + test-unit + test-smoke"
	@echo "  clean       Remove log/ directory"

# --------------------------------------------------------------------------
# Lint
# --------------------------------------------------------------------------
lint:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "[SKIP] shellcheck not found — install with: brew install shellcheck / apt install shellcheck"; \
	else \
		echo "=== shellcheck ==="; \
		shellcheck -x $(SCRIPTS); \
		echo "=== shellcheck passed ==="; \
	fi

# --------------------------------------------------------------------------
# Unit tests
# --------------------------------------------------------------------------
test-unit:
	@echo "=== unit tests ==="
	bash tests/unit/test_runner.sh
	@echo "=== unit tests passed ==="

# --------------------------------------------------------------------------
# Smoke tests
# --------------------------------------------------------------------------
test-smoke:
	@echo "=== smoke tests ==="
	bash smoke_test.sh
	@echo "=== smoke tests passed ==="

# --------------------------------------------------------------------------
# All tests
# --------------------------------------------------------------------------
test: lint test-unit test-smoke
	@echo ""
	@echo "=== ALL TESTS PASSED ==="

# --------------------------------------------------------------------------
# Clean
# --------------------------------------------------------------------------
clean:
	rm -rf log/
	rm -f log/*.json
