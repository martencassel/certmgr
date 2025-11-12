#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"
  run_certmgr_silent init >/dev/null 2>&1
}

@test "ca create: creates CA with minimal options" {
  run_certmgr ca create -n testca
  assert_success
  assert_dir_exists "$CERTMGR_DIR/CAs/testca"
  assert_file_exists "$CERTMGR_DIR/CAs/testca/private.key"
  assert_file_exists "$CERTMGR_DIR/CAs/testca/ca.crt"
  assert_file_exists "$CERTMGR_DIR/CAs/testca/serial.txt"
  assert_file_exists "$CERTMGR_DIR/CAs/testca/index.txt"
}

@test "ca create: uses custom subject" {
  run_certmgr ca create -n myca --subject "/C=US/O=Acme/CN=Acme Root"
  assert_success
  local cert="$CERTMGR_DIR/CAs/myca/ca.crt"
  assert_file_exists "$cert"

  # Verify subject
  local subject=$(openssl x509 -noout -subject -in "$cert")
  [[ "$subject" == *"CN = Acme Root"* ]]
}

@test "ca create: uses custom key bits" {
  run_certmgr ca create -n smallca --key-bits 2048
  assert_success

  # Verify key size
  local key="$CERTMGR_DIR/CAs/smallca/private.key"
  local bits=$(openssl rsa -noout -text -in "$key" 2>/dev/null | head -n1 | grep -oE '[0-9]+' | head -n1)
  [[ "$bits" == "2048" ]]
}

@test "ca create: uses custom validity days" {
  run_certmgr ca create -n shortca --days 365
  assert_success
  assert_file_exists "$CERTMGR_DIR/CAs/shortca/ca.crt"
}

@test "ca create: fails without name" {
  run_certmgr ca create
  assert_failure
  assert_output_contains "CA name is required"
}

@test "ca create: warns if CA already exists" {
  run_certmgr ca create -n testca
  assert_success
  run_certmgr ca create -n testca
  assert_success
  assert_output_contains "already exists"
}

@test "ca list: shows created CAs" {
  run_certmgr_silent ca create -n ca1
  run_certmgr_silent ca create -n ca2

  run_certmgr ca list
  assert_success
  assert_output_contains "ca1"
  assert_output_contains "ca2"
}

@test "ca list: handles empty CA directory" {
  run_certmgr ca list
  assert_success
  assert_output_contains "No CAs present"
}

@test "ca show: displays CA details" {
  run_certmgr_silent ca create -n testca >/dev/null 2>&1

  run_certmgr ca show -n testca
  assert_success
  assert_output_contains "testca"
  assert_output_contains "Path:"
  assert_output_contains "Cert:"
  assert_output_contains "fingerprint"
}

@test "ca show: fails for non-existent CA" {
  run_certmgr ca show -n nonexistent
  assert_failure
  assert_output_contains "not found"
}

@test "ca show: requires name" {
  run_certmgr ca show
  assert_failure
  assert_output_contains "CA name is required"
}
