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

@test "alias: 'certmgr c' works as 'certmgr ca'" {
  run_certmgr c list
  assert_success
  assert_output_contains "testca"
}

@test "alias: 'certmgr ca new' works as 'certmgr ca create'" {
  run_certmgr ca new -n newca
  assert_success
  assert_dir_exists "$CERTMGR_DIR/CAs/newca"
}

@test "alias: 'certmgr ca ls' works as 'certmgr ca list'" {
  run_certmgr ca ls
  assert_success
  assert_output_contains "testca"
}

@test "alias: 'certmgr i' works as 'certmgr cert issue'" {
  run_certmgr i -n quickserver
  assert_success
  assert_file_exists "$CERTMGR_DIR/issued/quickserver/server.crt"
}

@test "alias: 'certmgr cert ls' works as 'certmgr cert list'" {
  run_certmgr_silent cert issue -n server01 >/dev/null 2>&1

  run_certmgr cert ls
  assert_success
  assert_output_contains "server01"
}

@test "alias: 'certmgr c new' combines both aliases" {
  run_certmgr c new -n combo-ca
  assert_success
  assert_dir_exists "$CERTMGR_DIR/CAs/combo-ca"
}

@test "alias: 'certmgr c ls' combines both aliases" {
  run_certmgr c ls
  assert_success
  assert_output_contains "testca"
}
