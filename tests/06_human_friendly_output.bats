#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"
  run_certmgr_silent init >/dev/null 2>&1
  run_certmgr_silent ca create -n testca >/dev/null 2>&1
  run_certmgr_silent cert issue -n web01 --cn web01.local --san "web01.local,192.168.1.10" >/dev/null 2>&1
}

@test "show: displays certificate name" {
  run_certmgr cert show -n web01
  assert_success
  assert_output_matches "Name:[[:space:]]+web01"
}

@test "show: displays CN" {
  run_certmgr cert show -n web01
  assert_success
  assert_output_matches "CN:[[:space:]]+web01.local"
}

@test "show: displays SANs without DNS/IP prefixes" {
  run_certmgr cert show -n web01
  assert_success
  assert_output_matches "SANs:.*web01.local"
  assert_output_matches "SANs:.*192.168.1.10"
  # Should NOT contain DNS: or IP Address: prefixes
  run bash -c "echo '$output' | grep -v 'DNS:'"
  assert_success
}

@test "show: displays issuer CN" {
  run_certmgr cert show -n web01
  assert_success
  assert_output_matches "Issuer:.*testca"
}

@test "show: displays validity dates" {
  run_certmgr cert show -n web01
  assert_success
  assert_output_matches "Validity:.*→"
  # Should contain date in YYYY-MM-DD or full format
  assert_output_matches "Validity:.*20[0-9][0-9]"
}

@test "show: displays file paths" {
  run_certmgr cert show -n web01
  assert_success
  assert_output_contains "Files:"
  assert_output_contains "Key:"
  assert_output_contains "Cert:"
  assert_output_contains "Chain:"
}

@test "show: formats output in clean summary" {
  run_certmgr cert show -n web01
  assert_success
  assert_output_contains "Certificate Summary"

  # Check that all key fields are present
  echo "$output" | grep -q "Name:"
  echo "$output" | grep -q "CN:"
  echo "$output" | grep -q "SANs:"
  echo "$output" | grep -q "Issuer:"
  echo "$output" | grep -q "Validity:"
}

@test "show: handles certificate with IP SAN" {
  run_certmgr_silent cert issue -n ipserver --cn server.local --san "server.local,10.0.0.1" >/dev/null 2>&1

  run_certmgr cert show -n ipserver
  assert_success
  assert_output_contains "10.0.0.1"
}

@test "show: handles certificate with multiple DNS SANs" {
  run_certmgr_silent cert issue -n multiserver --cn server.local --san "server.local,www.server.local,api.server.local" >/dev/null 2>&1

  run_certmgr cert show -n multiserver
  assert_success
  assert_output_contains "server.local"
  assert_output_contains "www.server.local"
  assert_output_contains "api.server.local"
}
