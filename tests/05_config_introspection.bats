#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"
  run_certmgr_silent init >/dev/null 2>&1
}

@test "config: shows default configuration" {
  run_certmgr config
  assert_success
  assert_output_contains "Current Configuration"
  assert_output_contains "Config file:"
  assert_output_contains "Base directory:"
  assert_output_contains "OpenSSL"
}

@test "config: shows configuration sources" {
  run_certmgr config
  assert_success
  assert_output_contains "Configuration Sources"
  assert_output_contains "[default]"
  assert_output_contains "[yaml:key]"
  assert_output_contains "[env:VAR]"
}

@test "config: indicates default source for base_dir" {
  unset CERTMGR_DIR
  unset CERTMGR_CONFIG
  run_certmgr config
  assert_success
  assert_output_matches "Base directory:.*\[default\]"
}

@test "config: indicates env source when CERTMGR_DIR is set" {
  export CERTMGR_DIR="$TEST_DIR/env-certs"
  run_certmgr config
  assert_success
  assert_output_matches "Base directory:.*\[env:CERTMGR_DIR\]"
}

@test "config: indicates yaml source when base_dir is in YAML" {
  unset CERTMGR_DIR
  create_test_yaml "yaml-certs"
  run_certmgr_silent init >/dev/null 2>&1

  run_certmgr config
  assert_success
  assert_output_matches "Base directory:.*\[yaml:base_dir\]"
}

@test "config: shows environment variables section" {
  run_certmgr config
  assert_success
  assert_output_contains "Environment Variables:"
  assert_output_contains "CERTMGR_CONFIG:"
  assert_output_contains "CERTMGR_DIR:"
  assert_output_contains "OPENSSL_BIN:"
}

@test "config: highlights set environment variables" {
  export CERTMGR_DIR="$TEST_DIR/custom"
  run_certmgr config
  assert_success
  assert_output_contains "CERTMGR_DIR:"
  # Should show the custom path, not "(not set)"
  assert_output_contains "custom"
}

@test "config: shows YAML configuration when file exists" {
  create_test_yaml "test-base"

  run_certmgr config
  assert_success
  assert_output_contains "YAML Configuration:"
  assert_output_contains "base_dir:"
  assert_output_contains "test-base"
}

@test "config: shows CA and cert counts" {
  run_certmgr_silent ca create -n testca >/dev/null 2>&1
  run_certmgr_silent cert issue -n server01 >/dev/null 2>&1

  run_certmgr config
  assert_success
  assert_output_contains "(1 CAs)"
  assert_output_contains "(1 certs)"
}

@test "config: shows OpenSSL version" {
  run_certmgr config
  assert_success
  assert_output_matches "OpenSSL.*\(v[0-9]"
}
