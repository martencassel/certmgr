#!/usr/bin/env bats

load test_helper

@test "init: creates directory structure" {
  run_certmgr init
  assert_success
  assert_dir_exists "$CERTMGR_DIR"
  assert_dir_exists "$CERTMGR_DIR/CAs"
  assert_dir_exists "$CERTMGR_DIR/issued"
}

@test "init: works with custom CERTMGR_DIR" {
  export CERTMGR_DIR="$TEST_DIR/custom-certs"
  run_certmgr init
  assert_success
  assert_dir_exists "$TEST_DIR/custom-certs/CAs"
  assert_dir_exists "$TEST_DIR/custom-certs/issued"
}

@test "init: is idempotent" {
  run_certmgr init
  assert_success
  run_certmgr init
  assert_success
  assert_dir_exists "$CERTMGR_DIR"
}

@test "init: respects YAML base_dir configuration" {
  create_test_yaml "yaml-certs"
  run_certmgr init
  assert_success
  # Should create directories under yaml-certs
  assert_output_contains "yaml-certs"
}
