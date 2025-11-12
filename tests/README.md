# certmgr Testing Suite

Comprehensive end-to-end test suite for certmgr using BATS (Bash Automated Testing System).

## Prerequisites

Install BATS:

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
apt-get install bats

# npm
npm install -g bats
```

## Running Tests

### Quick Start

```bash
# Run all tests
make test

# Run specific test suite
make test-init       # Initialization tests
make test-ca         # CA operation tests
make test-cert       # Certificate issuance tests
make test-aliases    # Command alias tests
make test-config     # Config introspection tests
make test-output     # Human-friendly output tests
make test-e2e        # End-to-end workflow tests

# Run quick smoke tests
make test-quick

# View test coverage
make test-coverage
```

### Test Suites

#### 01_init.bats
Tests initialization functionality:
- Directory structure creation
- Custom CERTMGR_DIR handling
- Idempotency
- YAML configuration respect

#### 02_ca_operations.bats
Tests CA management:
- CA creation with various options
- CA listing
- CA details display
- Subject customization
- Key size and validity options
- Error handling

#### 03_cert_issuance.bats
Tests certificate issuance:
- Minimal certificate creation
- Auto-detection of CN and SAN
- Custom CN and SAN configuration
- Multi-SAN support
- CA auto-selection
- Certificate validation
- Chain building

#### 04_aliases.bats
Tests command aliases:
- Short commands (i, c, ls, new)
- Alias combinations
- Functional equivalence

#### 05_config_introspection.bats
Tests configuration display:
- Default configuration display
- Source attribution (default/yaml/env)
- Environment variable handling
- YAML configuration parsing
- Resource counting

#### 06_human_friendly_output.bats
Tests output formatting:
- Certificate summary display
- CN and SAN extraction
- Issuer display
- Validity date formatting
- Multi-SAN formatting

#### 07_e2e_workflows.bats
Tests complete workflows:
- Full workflow from init to inspection
- Alias-based workflow
- Multi-CA environment
- YAML configuration override
- Environment variable override
- Complex certificates

## Test Helper Functions

Located in `tests/test_helper.bash`:

### Setup/Teardown
- `setup()` - Creates isolated test environment
- `teardown()` - Cleans up test artifacts

### Assertions
- `assert_success()` - Command succeeded
- `assert_failure()` - Command failed
- `assert_file_exists(file)` - File exists
- `assert_dir_exists(dir)` - Directory exists
- `assert_output_contains(string)` - Output contains string
- `assert_output_matches(pattern)` - Output matches regex

### Utilities
- `run_certmgr(args...)` - Run certmgr command
- `create_test_yaml(base_dir)` - Create test YAML config
- `verify_cert(cert_file)` - Verify certificate validity
- `get_cert_cn(cert_file)` - Extract certificate CN
- `get_cert_sans(cert_file)` - Extract certificate SANs
- `count_files(dir)` - Count files in directory

## Test Fixtures

Sample YAML configurations in `tests/fixtures/`:

- `basic-config.yaml` - Multi-CA setup (prod/staging/dev)
- `minimal-config.yaml` - Minimal base_dir override
- `advanced-config.yaml` - Complex multi-purpose CA setup
- `custom-openssl.yaml` - Custom OpenSSL path configuration

## Continuous Integration

```bash
# Full CI pipeline
make ci

# Generate JUnit XML report
make ci-report
```

## Development

```bash
# Check script syntax
make check

# Lint with shellcheck
make lint

# Format test files
make format

# Run all checks
make test-all
```

## Demos

```bash
# Basic workflow demo
make demo-basic

# Command aliases demo
make demo-aliases

# Multi-CA environment demo
make demo-multi-ca
```

## Test Output

Tests provide colored, descriptive output:
- ✔ Green checkmarks for passing tests
- ✖ Red X for failing tests
- Test names clearly describe what's being tested

## Writing New Tests

```bash
#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"
  bash "$CERTMGR" init >/dev/null 2>&1
}

@test "my new test" {
  run_certmgr some command
  assert_success
  assert_output_contains "expected output"
}
```

## Troubleshooting

### BATS not found
```bash
make setup-tests  # Will guide you to install BATS
```

### Tests failing
```bash
make test-verbose  # Run with verbose output
```

### Clean up artifacts
```bash
make clean         # Remove test artifacts
make clean-all     # Deep clean
```

## Coverage

Current test coverage:
- 60+ test cases
- 7 test suites
- All major features covered
- E2E workflow validation
- Error condition testing
