#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"
  run_certmgr_silent init >/dev/null 2>&1
  run_certmgr_silent ca create -n testca >/dev/null 2>&1
}

@test "cert issue: creates certificate with minimal options" {
  run_certmgr cert issue -n server01
  assert_success
  assert_dir_exists "$CERTMGR_DIR/issued/server01"
  assert_file_exists "$CERTMGR_DIR/issued/server01/server.key"
  assert_file_exists "$CERTMGR_DIR/issued/server01/server.csr"
  assert_file_exists "$CERTMGR_DIR/issued/server01/server.crt"
  assert_file_exists "$CERTMGR_DIR/issued/server01/chain.crt"
  assert_file_exists "$CERTMGR_DIR/issued/server01/openssl.cnf"
}

@test "cert issue: auto-detects CN from name" {
  run_certmgr cert issue -n myserver
  assert_success
  assert_output_contains "Auto-detected CN from name: myserver"

  local cert="$CERTMGR_DIR/issued/myserver/server.crt"
  local cn=$(get_cert_cn "$cert")
  [[ "$cn" == "myserver" ]]
}

@test "cert issue: auto-populates SAN with CN" {
  run_certmgr cert issue -n webserver
  assert_success
  assert_output_contains "Auto-populated SAN with CN"

  local cert="$CERTMGR_DIR/issued/webserver/server.crt"
  local sans=$(get_cert_sans "$cert")
  [[ "$sans" == *"webserver"* ]]
}

@test "cert issue: uses custom CN" {
  run_certmgr cert issue -n server01 --cn custom.example.com
  assert_success

  local cert="$CERTMGR_DIR/issued/server01/server.crt"
  local cn=$(get_cert_cn "$cert")
  [[ "$cn" == "custom.example.com" ]]
}

@test "cert issue: uses custom SANs" {
  run_certmgr cert issue -n web01 --cn web01.local --san "web01.local,192.168.1.10"
  assert_success

  local cert="$CERTMGR_DIR/issued/web01/server.crt"
  local sans=$(get_cert_sans "$cert")
  [[ "$sans" == *"web01.local"* ]]
  [[ "$sans" == *"192.168.1.10"* ]]
}

@test "cert issue: auto-selects CA when only one exists" {
  run_certmgr cert issue -n autoserver
  assert_success
  assert_output_contains "Auto-selected CA: testca"
}

@test "cert issue: fails without CA when multiple exist" {
  run_certmgr_silent ca create -n testca2 >/dev/null 2>&1

  run_certmgr cert issue -n server01
  assert_failure
  assert_output_contains "CA name is required"
}

@test "cert issue: uses specified CA" {
  run_certmgr_silent ca create -n myca >/dev/null 2>&1

  run_certmgr cert issue -n server01 --ca myca
  assert_success
  assert_output_contains "via CA 'myca'"
}

@test "cert issue: fails without name" {
  run_certmgr cert issue
  assert_failure
  assert_output_contains "Output name is required"
}

@test "cert issue: creates valid certificate" {
  run_certmgr_silent cert issue -n validserver >/dev/null 2>&1

  local cert="$CERTMGR_DIR/issued/validserver/server.crt"
  verify_cert "$cert"
}

@test "cert issue: chain contains leaf and CA cert" {
  run_certmgr_silent cert issue -n chaintest >/dev/null 2>&1

  local chain="$CERTMGR_DIR/issued/chaintest/chain.crt"
  local cert_count=$(grep -c "BEGIN CERTIFICATE" "$chain")
  [[ "$cert_count" -eq 2 ]]
}

@test "cert list: shows issued certificates" {
  run_certmgr_silent cert issue -n cert1 >/dev/null 2>&1
  run_certmgr_silent cert issue -n cert2 >/dev/null 2>&1

  run_certmgr cert list
  assert_success
  assert_output_contains "cert1"
  assert_output_contains "cert2"
}

@test "cert list: handles no certificates" {
  run_certmgr cert list
  assert_success
  assert_output_contains "No certificates present"
}

@test "cert show: displays certificate summary" {
  run_certmgr_silent cert issue -n web01 --cn web01.local --san "web01.local,192.168.1.10" >/dev/null 2>&1

  run_certmgr cert show -n web01
  assert_success
  assert_output_contains "Name:"
  assert_output_contains "web01"
  assert_output_contains "CN:"
  assert_output_contains "web01.local"
  assert_output_contains "SANs:"
  assert_output_contains "Issuer:"
  assert_output_contains "Validity:"
}

@test "cert show: fails for non-existent certificate" {
  run_certmgr cert show -n nonexistent
  assert_failure
  assert_output_contains "not found"
}

@test "cert show: requires name" {
  run_certmgr cert show
  assert_failure
  assert_output_contains "Name is required"
}
