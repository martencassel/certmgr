#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"
}

@test "e2e: complete workflow from init to cert inspection" {
  # Initialize
  run_certmgr init
  assert_success

  # Create CA
  run_certmgr ca create -n production-ca --subject "/C=US/O=Example/CN=Example Root"
  assert_success

  # List CAs
  run_certmgr ca list
  assert_success
  assert_output_contains "production-ca"

  # Issue certificate
  run_certmgr cert issue -n webserver --cn web.example.com --san "web.example.com,www.example.com,192.168.1.100"
  assert_success

  # List certificates
  run_certmgr cert list
  assert_success
  assert_output_contains "webserver"

  # Show certificate details
  run_certmgr cert show -n webserver
  assert_success
  assert_output_contains "web.example.com"
  assert_output_contains "192.168.1.100"

  # View configuration
  run_certmgr config
  assert_success
  assert_output_contains "(1 CAs)"
  assert_output_contains "(1 certs)"
}

@test "e2e: workflow using aliases" {
  run_certmgr_silent init >/dev/null 2>&1

  # Create CA with alias
  run_certmgr c new -n testca
  assert_success

  # List with alias
  run_certmgr c ls
  assert_success
  assert_output_contains "testca"

  # Issue cert with short alias
  run_certmgr i -n server01
  assert_success

  # List certs with alias
  run_certmgr cert ls
  assert_success
  assert_output_contains "server01"
}

@test "e2e: multi-CA environment" {
  run_certmgr_silent init >/dev/null 2>&1

  # Create multiple CAs
  run_certmgr_silent ca create -n root-ca >/dev/null 2>&1
  run_certmgr_silent ca create -n dev-ca >/dev/null 2>&1
  run_certmgr_silent ca create -n staging-ca >/dev/null 2>&1

  # List all CAs
  run_certmgr ca list
  assert_success
  assert_output_contains "root-ca"
  assert_output_contains "dev-ca"
  assert_output_contains "staging-ca"

  # Issue cert from specific CA
  run_certmgr cert issue -n dev-server --ca dev-ca
  assert_success

  # Issue cert from different CA
  run_certmgr cert issue -n staging-server --ca staging-ca
  assert_success

  # Verify both certs exist
  run_certmgr cert list
  assert_success
  assert_output_contains "dev-server"
  assert_output_contains "staging-server"
}

@test "e2e: YAML configuration override" {
  # Unset env vars so YAML config takes precedence
  unset CERTMGR_DIR
  create_test_yaml "custom-certs"

  # Init should use YAML config
  run_certmgr init
  assert_success
  assert_output_contains "custom-certs"

  # Create CA from YAML config
  run_certmgr ca create -n testca
  assert_success

  # Config should show YAML source
  run_certmgr config
  assert_success
  assert_output_contains "yaml:base_dir"
  assert_output_contains "custom-certs"
}

@test "e2e: environment variable override" {
  export CERTMGR_DIR="$TEST_DIR/env-override"

  run_certmgr_silent init >/dev/null 2>&1

  # Config should show env source
  run_certmgr config
  assert_success
  assert_output_contains "env:CERTMGR_DIR"
  assert_output_contains "env-override"

  # Operations should work with override
  run_certmgr_silent ca create -n testca >/dev/null 2>&1
  run_certmgr_silent cert issue -n server01 >/dev/null 2>&1

  # Verify files are in override location
  assert_dir_exists "$TEST_DIR/env-override/CAs/testca"
  assert_dir_exists "$TEST_DIR/env-override/issued/server01"
}

@test "e2e: complex certificate with multiple SANs" {
  run_certmgr_silent init >/dev/null 2>&1
  run_certmgr_silent ca create -n testca >/dev/null 2>&1

  # Issue cert with multiple DNS and IP SANs
  run_certmgr cert issue -n complex \
    --cn app.example.com \
    --san "app.example.com,www.app.example.com,api.app.example.com,10.0.0.1,10.0.0.2"
  assert_success

  # Verify all SANs are in certificate
  local cert="$CERTMGR_DIR/issued/complex/server.crt"
  local sans=$(get_cert_sans "$cert")
  [[ "$sans" == *"app.example.com"* ]]
  [[ "$sans" == *"www.app.example.com"* ]]
  [[ "$sans" == *"api.app.example.com"* ]]
  [[ "$sans" == *"10.0.0.1"* ]]
  [[ "$sans" == *"10.0.0.2"* ]]
}

@test "e2e: minimal workflow - auto-everything" {
  run_certmgr_silent init >/dev/null 2>&1
  run_certmgr_silent ca create -n auto-ca >/dev/null 2>&1

  # Issue cert with just name - everything else auto
  run_certmgr cert issue -n minimal-server
  assert_success
  assert_output_contains "Auto-detected CN"
  assert_output_contains "Auto-populated SAN"
  assert_output_contains "Auto-selected CA"

  # Verify cert was created correctly
  local cert="$CERTMGR_DIR/issued/minimal-server/server.crt"
  verify_cert "$cert"

  local cn=$(get_cert_cn "$cert")
  [[ "$cn" == "minimal-server" ]]
}

@test "e2e: getting started workflow from help" {
  # This tests the exact workflow shown in "certmgr help" under "Getting Started"

  # Step 1: Initialize storage: certmgr init
  run_certmgr init
  assert_success
  assert_dir_exists "$CERTMGR_DIR"
  assert_dir_exists "$CERTMGR_DIR/CAs"
  assert_dir_exists "$CERTMGR_DIR/issued"

  # Step 2: Create a CA: certmgr ca create -n myca
  run_certmgr ca create -n myca
  assert_success
  assert_file_exists "$CERTMGR_DIR/CAs/myca/ca.crt"
  assert_file_exists "$CERTMGR_DIR/CAs/myca/private.key"

  # Step 3: Issue a cert (minimal): certmgr cert issue -n myserver
  # (CN, SAN, and CA auto-populated from name)
  run_certmgr cert issue -n myserver
  assert_success
  assert_output_contains "Auto-detected CN from name: myserver"
  assert_output_contains "Auto-populated SAN with CN"
  assert_output_contains "Auto-selected CA: myca"

  # Verify the certificate was created with auto-populated values
  local cert="$CERTMGR_DIR/issued/myserver/server.crt"
  assert_file_exists "$cert"
  verify_cert "$cert"

  # Verify CN matches name
  local cn=$(get_cert_cn "$cert")
  [[ "$cn" == "myserver" ]]

  # Verify SAN matches CN
  local sans=$(get_cert_sans "$cert")
  [[ "$sans" == *"myserver"* ]]

  # Step 4: Or with custom values: certmgr cert issue -n myserver --cn server.local --san server.local,192.168.1.10
  run_certmgr cert issue -n myserver2 --cn server.local --san "server.local,192.168.1.10"
  assert_success

  local cert2="$CERTMGR_DIR/issued/myserver2/server.crt"
  assert_file_exists "$cert2"

  # Verify custom values
  local cn2=$(get_cert_cn "$cert2")
  [[ "$cn2" == "server.local" ]]

  local sans2=$(get_cert_sans "$cert2")
  [[ "$sans2" == *"server.local"* ]]
  [[ "$sans2" == *"192.168.1.10"* ]]

  # Step 5: Check your certificates: certmgr cert list
  run_certmgr cert list
  assert_success
  assert_output_contains "myserver"
  assert_output_contains "myserver2"

  # Step 6: View config anytime: certmgr config
  run_certmgr config
  assert_success
  assert_output_contains "Current Configuration"
  assert_output_contains "(1 CAs)"
  assert_output_contains "(2 certs)"
  assert_output_contains "Configuration Sources"
}
