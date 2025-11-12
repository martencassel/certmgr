#!/usr/bin/env bash

# ============================================================
# BATS Test Helper for certmgr
# ============================================================

# Test configuration
export BATS_TEST_TIMEOUT=30
export CERTMGR="${BATS_TEST_DIRNAME}/../certmgr"

# Setup function - runs before each test
setup() {
  # Create a unique temporary directory for this test
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"

  # Ensure we're using the test environment
  cd "$TEST_DIR"
}

# Teardown function - runs after each test
teardown() {
  # Clean up test directory
  if [[ -n "${TEST_DIR:-}" ]] && [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# Helper: Run certmgr command
run_certmgr() {
  run bash "$CERTMGR" "$@"
}

# Helper: Run certmgr command silently (for setup)
run_certmgr_silent() {
  bash "$CERTMGR" "$@" >/dev/null 2>&1 || true
}

# Helper: Check if a file exists
assert_file_exists() {
  local file="$1"
  [[ -f "$file" ]] || {
    echo "Expected file does not exist: $file" >&2
    return 1
  }
}

# Helper: Check if a directory exists
assert_dir_exists() {
  local dir="$1"
  [[ -d "$dir" ]] || {
    echo "Expected directory does not exist: $dir" >&2
    return 1
  }
}

# Helper: Check if output contains string
assert_output_contains() {
  local expected="$1"
  echo "$output" | grep -q "$expected" || {
    echo "Output does not contain expected string: $expected" >&2
    echo "Actual output:" >&2
    echo "$output" >&2
    return 1
  }
}

# Helper: Check if output matches regex
assert_output_matches() {
  local pattern="$1"
  echo "$output" | grep -qE "$pattern" || {
    echo "Output does not match pattern: $pattern" >&2
    echo "Actual output:" >&2
    echo "$output" >&2
    return 1
  }
}

# Helper: Check command succeeded
assert_success() {
  [[ "$status" -eq 0 ]] || {
    echo "Command failed with status $status" >&2
    echo "Output:" >&2
    echo "$output" >&2
    return 1
  }
}

# Helper: Check command failed
assert_failure() {
  [[ "$status" -ne 0 ]] || {
    echo "Command succeeded but was expected to fail" >&2
    echo "Output:" >&2
    echo "$output" >&2
    return 1
  }
}

# Helper: Create a test YAML config
create_test_yaml() {
  local base_dir="${1:-testcerts}"
  cat > "$CERTMGR_CONFIG" <<EOF
base_dir: $base_dir
openssl_bin: openssl
cas:
  testca:
    subject: "/C=SE/O=Test/CN=Test CA"
    days: 365
    key_bits: 2048
    digest: sha256
EOF
}

# Helper: Verify certificate is valid
verify_cert() {
  local cert_file="$1"
  openssl x509 -noout -text -in "$cert_file" >/dev/null 2>&1
}

# Helper: Get certificate CN
get_cert_cn() {
  local cert_file="$1"
  openssl x509 -noout -subject -in "$cert_file" 2>/dev/null | \
    sed -n 's/.*CN[[:space:]]*=[[:space:]]*\([^,/]*\).*/\1/p'
}

# Helper: Get certificate SANs
get_cert_sans() {
  local cert_file="$1"
  openssl x509 -noout -text -in "$cert_file" 2>/dev/null | \
    awk '/Subject Alternative Name/ {getline; gsub(/^[[:space:]]+/, ""); print}'
}

# Helper: Count files in directory
count_files() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l
}
