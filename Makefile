# ============================================================
# Makefile for certmgr - Certificate Manager
# ============================================================

# Colors for output
BOLD := \033[1m
RESET := \033[0m
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m

# Project variables
PROJECT_NAME := certmgr
SCRIPT := ./certmgr
TEST_DIR := ./tests
BATS := bats

# Default target
.DEFAULT_GOAL := help

# Phony targets
.PHONY: help test test-init test-ca test-cert test-aliases test-config test-output test-e2e \
        test-verbose test-coverage clean install check lint format setup-tests \
        test-quick test-all demo-basic demo-aliases demo-multi-ca

##@ Help

help: ## Display this help message
	@printf "$(BOLD)$(CYAN)%s$(RESET)\n" "$(PROJECT_NAME) - Certificate Manager"
	@printf "\n"
	@printf "$(BOLD)Usage:$(RESET)\n"
	@printf "  make $(CYAN)<target>$(RESET)\n"
	@printf "\n"
	@awk 'BEGIN {FS = ":.*##"; printf "$(BOLD)Targets:$(RESET)\n"} \
		/^[a-zA-Z_-]+:.*?##/ { \
			printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 \
		} \
		/^##@/ { \
			printf "\n$(BOLD)$(MAGENTA)%s$(RESET)\n", substr($$0, 5) \
		}' $(MAKEFILE_LIST)

##@ Testing

test: setup-tests ## Run all tests
	@printf "$(BOLD)$(BLUE)Running all tests...$(RESET)\n"
	@$(BATS) $(TEST_DIR)/*.bats || (printf "$(RED)✖ Tests failed$(RESET)\n"; exit 1)
	@printf "$(GREEN)✔ All tests passed!$(RESET)\n"

test-init: setup-tests ## Run initialization tests
	@printf "$(BOLD)$(BLUE)Testing: Initialization$(RESET)\n"
	@$(BATS) $(TEST_DIR)/01_init.bats

test-ca: setup-tests ## Run CA operation tests
	@printf "$(BOLD)$(BLUE)Testing: CA Operations$(RESET)\n"
	@$(BATS) $(TEST_DIR)/02_ca_operations.bats

test-cert: setup-tests ## Run certificate issuance tests
	@printf "$(BOLD)$(BLUE)Testing: Certificate Issuance$(RESET)\n"
	@$(BATS) $(TEST_DIR)/03_cert_issuance.bats

test-aliases: setup-tests ## Run command alias tests
	@printf "$(BOLD)$(BLUE)Testing: Command Aliases$(RESET)\n"
	@$(BATS) $(TEST_DIR)/04_aliases.bats

test-config: setup-tests ## Run config introspection tests
	@printf "$(BOLD)$(BLUE)Testing: Config Introspection$(RESET)\n"
	@$(BATS) $(TEST_DIR)/05_config_introspection.bats

test-output: setup-tests ## Run human-friendly output tests
	@printf "$(BOLD)$(BLUE)Testing: Human-Friendly Output$(RESET)\n"
	@$(BATS) $(TEST_DIR)/06_human_friendly_output.bats

test-e2e: setup-tests ## Run end-to-end workflow tests
	@printf "$(BOLD)$(BLUE)Testing: E2E Workflows$(RESET)\n"
	@$(BATS) $(TEST_DIR)/07_e2e_workflows.bats

test-trust: setup-tests ## Run trust bundle tests
	@printf "$(BOLD)$(BLUE)Testing: Trust Bundles$(RESET)\n"
	@$(BATS) $(TEST_DIR)/08_trust_bundles.bats

test-verify: setup-tests ## Run certificate verification tests
	@printf "$(BOLD)$(BLUE)Testing: Certificate Verification$(RESET)\n"
	@$(BATS) $(TEST_DIR)/09_verify.bats

test-verbose: setup-tests ## Run all tests with verbose output
	@printf "$(BOLD)$(BLUE)Running all tests (verbose)...$(RESET)\n"
	@$(BATS) --verbose-run $(TEST_DIR)/*.bats

test-quick: setup-tests ## Run quick smoke tests (init + basic operations)
	@printf "$(BOLD)$(BLUE)Running quick smoke tests...$(RESET)\n"
	@$(BATS) $(TEST_DIR)/01_init.bats $(TEST_DIR)/02_ca_operations.bats

test-all: setup-tests test lint ## Run tests and linting
	@printf "$(GREEN)✔ All checks passed!$(RESET)\n"

test-coverage: setup-tests ## Run tests and show coverage summary
	@printf "$(BOLD)$(BLUE)Test Coverage Summary:$(RESET)\n"
	@total=$$(grep -c "^@test" $(TEST_DIR)/*.bats); \
	printf "  Total test cases: $(CYAN)%s$(RESET)\n" "$$total"
	@printf "  Test suites:\n"
	@for file in $(TEST_DIR)/*.bats; do \
		count=$$(grep -c "^@test" "$$file"); \
		name=$$(basename "$$file" .bats); \
		printf "    $(YELLOW)%-25s$(RESET) %s tests\n" "$$name" "$$count"; \
	done

##@ Development

check: ## Check if certmgr script is executable and valid
	@printf "$(BOLD)$(BLUE)Checking certmgr script...$(RESET)\n"
	@if [ ! -f "$(SCRIPT)" ]; then \
		printf "$(RED)✖ Script not found: $(SCRIPT)$(RESET)\n"; \
		exit 1; \
	fi
	@if [ ! -x "$(SCRIPT)" ]; then \
		printf "$(YELLOW)⚠ Script not executable, fixing...$(RESET)\n"; \
		chmod +x "$(SCRIPT)"; \
	fi
	@bash -n "$(SCRIPT)" && printf "$(GREEN)✔ Script syntax is valid$(RESET)\n" || \
		(printf "$(RED)✖ Script has syntax errors$(RESET)\n"; exit 1)

lint: check ## Lint the certmgr script using shellcheck
	@printf "$(BOLD)$(BLUE)Linting certmgr script...$(RESET)\n"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x "$(SCRIPT)" && \
		printf "$(GREEN)✔ No linting issues found$(RESET)\n" || \
		printf "$(YELLOW)⚠ Linting issues found$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠ shellcheck not installed, skipping lint$(RESET)\n"; \
	fi

format: ## Format test files (check bash formatting)
	@printf "$(BOLD)$(BLUE)Checking test file formatting...$(RESET)\n"
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -d $(TEST_DIR)/*.bats $(TEST_DIR)/test_helper.bash && \
		printf "$(GREEN)✔ All test files are properly formatted$(RESET)\n" || \
		printf "$(YELLOW)⚠ Some test files need formatting$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠ shfmt not installed, skipping format check$(RESET)\n"; \
	fi

setup-tests: ## Setup test environment (install bats if needed)
	@if ! command -v $(BATS) >/dev/null 2>&1; then \
		printf "$(YELLOW)⚠ BATS not found. Install it with:$(RESET)\n"; \
		printf "  $(CYAN)npm install -g bats$(RESET) or\n"; \
		printf "  $(CYAN)brew install bats-core$(RESET) or\n"; \
		printf "  $(CYAN)apt-get install bats$(RESET)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✔ BATS is installed$(RESET)\n"

##@ Demonstration

demo-basic: ## Run a basic demo workflow
	@printf "$(BOLD)$(MAGENTA)Demo: Basic Workflow$(RESET)\n\n"
	@printf "$(BOLD)1. Initialize storage$(RESET)\n"
	@$(SCRIPT) init
	@printf "\n$(BOLD)2. Create a CA$(RESET)\n"
	@$(SCRIPT) ca create -n demo-ca
	@printf "\n$(BOLD)3. List CAs$(RESET)\n"
	@$(SCRIPT) ca list
	@printf "\n$(BOLD)4. Issue a certificate$(RESET)\n"
	@$(SCRIPT) cert issue -n demo-server
	@printf "\n$(BOLD)5. List certificates$(RESET)\n"
	@$(SCRIPT) cert list
	@printf "\n$(BOLD)6. Show certificate details$(RESET)\n"
	@$(SCRIPT) cert show -n demo-server
	@printf "\n$(GREEN)✔ Demo completed!$(RESET)\n"

demo-aliases: ## Demo command aliases
	@printf "$(BOLD)$(MAGENTA)Demo: Command Aliases$(RESET)\n\n"
	@rm -rf certs
	@$(SCRIPT) init >/dev/null 2>&1
	@printf "$(BOLD)Short alias for CA create:$(RESET) $(CYAN)certmgr c new -n quick-ca$(RESET)\n"
	@$(SCRIPT) c new -n quick-ca
	@printf "\n$(BOLD)Short alias for CA list:$(RESET) $(CYAN)certmgr c ls$(RESET)\n"
	@$(SCRIPT) c ls
	@printf "\n$(BOLD)Short alias for cert issue:$(RESET) $(CYAN)certmgr i -n quick-server$(RESET)\n"
	@$(SCRIPT) i -n quick-server
	@printf "\n$(BOLD)Short alias for cert list:$(RESET) $(CYAN)certmgr cert ls$(RESET)\n"
	@$(SCRIPT) cert ls
	@printf "\n$(GREEN)✔ Aliases demo completed!$(RESET)\n"

demo-multi-ca: ## Demo multi-CA environment
	@printf "$(BOLD)$(MAGENTA)Demo: Multi-CA Environment$(RESET)\n\n"
	@rm -rf certs
	@$(SCRIPT) init >/dev/null 2>&1
	@printf "$(BOLD)Creating multiple CAs...$(RESET)\n"
	@$(SCRIPT) ca create -n production-ca --subject "/C=US/O=Prod/CN=Production Root" >/dev/null 2>&1
	@$(SCRIPT) ca create -n staging-ca --subject "/C=US/O=Staging/CN=Staging Root" >/dev/null 2>&1
	@$(SCRIPT) ca create -n development-ca --subject "/C=US/O=Dev/CN=Dev Root" >/dev/null 2>&1
	@$(SCRIPT) ca list
	@printf "\n$(BOLD)Issuing certificates from different CAs...$(RESET)\n"
	@$(SCRIPT) cert issue -n prod-web --ca production-ca --cn web.prod.example.com >/dev/null 2>&1
	@$(SCRIPT) cert issue -n staging-api --ca staging-ca --cn api.staging.example.com >/dev/null 2>&1
	@$(SCRIPT) cert issue -n dev-test --ca development-ca --cn test.dev.local >/dev/null 2>&1
	@$(SCRIPT) cert list
	@printf "\n$(BOLD)Showing certificate details:$(RESET)\n"
	@$(SCRIPT) cert show -n prod-web
	@printf "\n$(GREEN)✔ Multi-CA demo completed!$(RESET)\n"

##@ Cleanup

clean: ## Clean up test artifacts and demo certificates
	@printf "$(BOLD)$(BLUE)Cleaning up...$(RESET)\n"
	@rm -rf certs certmgr.yaml
	@printf "$(GREEN)✔ Cleanup complete$(RESET)\n"

clean-all: clean ## Deep clean (remove all generated files)
	@printf "$(BOLD)$(BLUE)Deep cleaning...$(RESET)\n"
	@find . -name "*.tmp" -type f -delete 2>/dev/null || true
	@find . -name ".DS_Store" -type f -delete 2>/dev/null || true
	@printf "$(GREEN)✔ Deep cleanup complete$(RESET)\n"

##@ Installation

install: check ## Install certmgr to /usr/local/bin
	@printf "$(BOLD)$(BLUE)Installing certmgr...$(RESET)\n"
	@if [ -w /usr/local/bin ]; then \
		cp "$(SCRIPT)" /usr/local/bin/certmgr; \
		chmod +x /usr/local/bin/certmgr; \
		printf "$(GREEN)✔ Installed to /usr/local/bin/certmgr$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠ Permission denied. Try: sudo make install$(RESET)\n"; \
		exit 1; \
	fi

uninstall: ## Uninstall certmgr from /usr/local/bin
	@printf "$(BOLD)$(BLUE)Uninstalling certmgr...$(RESET)\n"
	@if [ -f /usr/local/bin/certmgr ]; then \
		rm -f /usr/local/bin/certmgr; \
		printf "$(GREEN)✔ Uninstalled from /usr/local/bin$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠ certmgr not found in /usr/local/bin$(RESET)\n"; \
	fi

##@ CI/CD

ci: setup-tests check lint test ## Run CI pipeline (check, lint, test)
	@printf "$(BOLD)$(GREEN)✔ CI pipeline completed successfully!$(RESET)\n"

ci-report: setup-tests ## Generate CI test report
	@printf "$(BOLD)$(BLUE)Generating CI test report...$(RESET)\n"
	@$(BATS) --formatter junit $(TEST_DIR)/*.bats > test-results.xml 2>&1 || true
	@printf "$(GREEN)✔ Test report generated: test-results.xml$(RESET)\n"
