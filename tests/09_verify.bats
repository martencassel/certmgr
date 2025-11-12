#!/usr/bin/env bats
# Certificate verification tests

load test_helper

# Override setup to add CA and cert creation
setup() {
  # Create a unique temporary directory for this test
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"
  
  # Initialize and create test infrastructure
  run_certmgr_silent init
  run_certmgr_silent ca create -n testca --subject "/C=US/O=Test/CN=Test CA"
  run_certmgr_silent cert issue -n testcert --cn test.local --ca testca
  run_certmgr_silent trust bundle -n test-bundle --ca testca
}

# Use default teardown from test_helper

# File verification tests

@test "verify file: verifies certificate file" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt"
  assert_success
  assert_output_contains "Verifying certificate file"
  assert_output_contains "Certificate Information"
  assert_output_contains "Subject:"
  assert_output_contains "Issuer:"
  assert_output_contains "Valid From:"
  assert_output_contains "Valid Until:"
}

@test "verify file: checks certificate expiry" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt"
  assert_success
  assert_output_contains "Expiry Check"
  assert_output_contains "Certificate valid for"
}

@test "verify file: shows SANs" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt"
  assert_success
  assert_output_contains "Subject Alternative Names"
  assert_output_contains "test.local"
}

@test "verify file: shows key information" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt"
  assert_success
  assert_output_contains "Key Information"
  assert_output_contains "Public-Key:"
}

@test "verify file: shows fingerprints" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt"
  assert_success
  assert_output_contains "Fingerprints"
  assert_output_contains "SHA256:"
  assert_output_contains "SHA1:"
}

@test "verify file: fails with missing file" {
  run_certmgr verify file -f "$CERTMGR_DIR/nonexistent.crt"
  assert_failure
  assert_output_contains "Certificate file not found"
}

@test "verify file: requires file parameter" {
  run_certmgr verify file
  assert_failure
  assert_output_contains "Certificate file is required"
}

@test "verify file: verifies with custom CA file" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt" \
    --ca-file "$CERTMGR_DIR/CAs/testca/ca.crt"
  assert_success
  assert_output_contains "Using CA file:"
  assert_output_contains "Certificate chain is valid"
}

@test "verify file: verifies with trust bundle" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt" \
    --ca-bundle test-bundle
  assert_success
  assert_output_contains "Using trust bundle: test-bundle"
  assert_output_contains "Certificate chain is valid"
}

@test "verify file: fails with non-existent trust bundle" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt" \
    --ca-bundle nonexistent
  assert_failure
  assert_output_contains "Trust bundle 'nonexistent' not found"
}

@test "verify file: fails with non-existent CA file" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt" \
    --ca-file "/nonexistent/ca.crt"
  assert_failure
  assert_output_contains "CA file not found"
}

@test "verify file: warns when not trusted by system" {
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt"
  assert_success
  assert_output_contains "Certificate Chain Verification (System CA Store)"
  # Self-signed certs won't be trusted by system
  assert_output_contains "Certificate verification failed"
}

# URL verification tests (only test error handling, not actual connections)

@test "verify url: requires URL parameter" {
  run_certmgr verify url
  assert_failure
  assert_output_contains "URL is required"
}

@test "verify url: adds https prefix if missing" {
  # This will fail to connect but should process the URL correctly
  run_certmgr verify url -u localhost:9999 || true
  # Just check it doesn't error on URL processing
  [[ $status -eq 0 ]] || [[ $output =~ "Verifying TLS connection: localhost:9999" ]]
}

@test "verify url: accepts full https URL" {
  # This will fail to connect but should process the URL correctly
  run_certmgr verify url -u https://localhost:9999 || true
  # Just check it doesn't error on URL processing
  [[ $status -eq 0 ]] || [[ $output =~ "Verifying TLS connection: localhost:9999" ]]
}

# Command aliases

@test "verify: 'v' alias works for file" {
  run_certmgr v file -f "$CERTMGR_DIR/issued/testcert/server.crt"
  assert_success
  assert_output_contains "Verifying certificate file"
}

@test "verify: unknown subcommand shows error" {
  run_certmgr verify invalid
  assert_failure
  assert_output_contains "Unknown 'verify' subcommand"
  assert_output_contains "Use 'verify file' or 'verify url'"
}

# Integration tests

@test "verify: complete workflow with trust bundle" {
  # Create another CA and cert
  run_certmgr_silent ca create -n ca2 --subject "/C=US/O=Test2/CN=Test CA 2"
  run_certmgr_silent cert issue -n cert2 --cn cert2.local --ca ca2
  
  # Create trust bundle with both CAs
  run_certmgr_silent trust bundle -n multi-ca --ca testca,ca2
  
  # Verify first cert with multi-CA bundle
  run_certmgr verify file -f "$CERTMGR_DIR/issued/testcert/server.crt" \
    --ca-bundle multi-ca
  assert_success
  assert_output_contains "Certificate chain is valid"
  
  # Verify second cert with same bundle
  run_certmgr verify file -f "$CERTMGR_DIR/issued/cert2/server.crt" \
    --ca-bundle multi-ca
  assert_success
  assert_output_contains "Certificate chain is valid"
}

@test "verify: CA certificate verification" {
  # Verify a CA certificate itself
  run_certmgr verify file -f "$CERTMGR_DIR/CAs/testca/ca.crt"
  assert_success
  assert_output_contains "Certificate Information"
  assert_output_contains "CN = Test CA"
}

@test "verify: shows multiple SANs" {
  # Create cert with multiple SANs
  run_certmgr_silent cert issue -n multi-san --cn example.com \
    --san "example.com,www.example.com,api.example.com" --ca testca
  
  run_certmgr verify file -f "$CERTMGR_DIR/issued/multi-san/server.crt"
  assert_success
  assert_output_contains "example.com"
  assert_output_contains "www.example.com"
  assert_output_contains "api.example.com"
}
