.PHONY: test shellcheck unit smoke

test: shellcheck unit smoke ## Run full verification chain

shellcheck: ## Static analysis via shellcheck
	@bash test/run_shellcheck.sh

unit: ## Unit tests for helper/output functions
	@bash test/unit/test_helper_lib.sh
	@bash test/unit/test_output_lib.sh

smoke: ## Syntax check + main script smoke test
	@bash test/smoke.sh
