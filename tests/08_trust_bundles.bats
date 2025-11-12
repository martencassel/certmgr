#!/usr/bin/env bats
# Trust bundle operations tests

load test_helper

# Override setup to add CA creation
setup() {
  # Create a unique temporary directory for this test
  export TEST_DIR="$(mktemp -d -t certmgr-test-XXXXXX)"
  export CERTMGR_DIR="$TEST_DIR/certs"
  export CERTMGR_CONFIG="$TEST_DIR/certmgr.yaml"
  cd "$TEST_DIR"

  # Initialize and create test CAs
  run_certmgr_silent init
  run_certmgr_silent ca create -n testca1 --subject "/C=US/O=Test1/CN=Test CA 1"
  run_certmgr_silent ca create -n testca2 --subject "/C=US/O=Test2/CN=Test CA 2"
  run_certmgr_silent ca create -n testca3 --subject "/C=US/O=Test3/CN=Test CA 3"
}

# Use default teardown from test_helper

# Basic trust bundle operations

@test "trust bundle: creates bundle with all CAs" {
  run_certmgr trust bundle -n test-all --ca all
  assert_success
  assert_output_contains "Creating trust bundle 'test-all'"
  assert_output_contains "Including all CAs"
  assert_output_contains "Added CA 'testca1'"
  assert_output_contains "Added CA 'testca2'"
  assert_output_contains "Added CA 'testca3'"
  assert_file_exists "$CERTMGR_DIR/trust/test-all/bundle.pem"
  assert_file_exists "$CERTMGR_DIR/trust/test-all/metadata.txt"
}

@test "trust bundle: creates bundle with specific CAs" {
  run_certmgr trust bundle -n test-partial --ca testca1,testca3
  assert_success
  assert_output_contains "Creating trust bundle 'test-partial'"
  assert_output_contains "Added CA 'testca1'"
  assert_output_contains "Added CA 'testca3'"
  assert_file_exists "$CERTMGR_DIR/trust/test-partial/bundle.pem"

  # Verify only specified CAs are in the bundle
  local ca_count
  ca_count=$(grep -c "BEGIN CERTIFICATE" "$CERTMGR_DIR/trust/test-partial/bundle.pem")
  [[ $ca_count -eq 2 ]]
}

@test "trust bundle: fails without name" {
  run_certmgr trust bundle --ca all
  assert_failure
  assert_output_contains "Bundle name is required"
}

@test "trust bundle: fails without CA list" {
  run_certmgr trust bundle -n test-bundle
  assert_failure
  assert_output_contains "CA list is required"
}

@test "trust bundle: handles non-existent CA gracefully" {
  run_certmgr trust bundle -n test-missing --ca testca1,nonexistent,testca2
  assert_success
  assert_output_contains "CA 'nonexistent' not found"
  assert_output_contains "Added CA 'testca1'"
  assert_output_contains "Added CA 'testca2'"
}

@test "trust bundle: updates existing bundle" {
  run_certmgr_silent trust bundle -n test-update --ca testca1
  run_certmgr trust bundle -n test-update --ca testca1,testca2
  assert_success

  # Verify bundle was updated with both CAs
  local ca_count
  ca_count=$(grep -c "BEGIN CERTIFICATE" "$CERTMGR_DIR/trust/test-update/bundle.pem")
  [[ $ca_count -eq 2 ]]
}

# Trust bundle listing and inspection

@test "trust list: shows created bundles" {
  run_certmgr_silent trust bundle -n bundle1 --ca testca1
  run_certmgr_silent trust bundle -n bundle2 --ca testca1,testca2

  run_certmgr trust list
  assert_success
  assert_output_contains "Trust Bundles"
  assert_output_contains "bundle1"
  assert_output_contains "bundle2"
  assert_output_contains "(1 CA(s))"
  assert_output_contains "(2 CA(s))"
}

@test "trust list: handles empty trust directory" {
  run_certmgr trust list
  assert_success
  assert_output_contains "No trust bundles present"
}

@test "trust show: displays bundle details" {
  run_certmgr_silent trust bundle -n test-show --ca testca1,testca2

  run_certmgr trust show -n test-show
  assert_success
  assert_output_contains "Trust Bundle 'test-show'"
  assert_output_contains "Bundle file:"
  assert_output_contains "Included CAs:"
  assert_output_contains "CA: testca1"
  assert_output_contains "CA: testca2"
  assert_output_contains "Total certificates: 2"
  assert_output_contains "Bundle size:"
}

@test "trust show: fails for non-existent bundle" {
  run_certmgr trust show -n nonexistent
  assert_failure
  assert_output_contains "Trust bundle 'nonexistent' not found"
}

# Export formats

@test "trust export: exports PEM format to stdout" {
  run_certmgr_silent trust bundle -n test-pem --ca testca1

  run_certmgr trust export -n test-pem --format pem
  assert_success
  assert_output_contains "BEGIN CERTIFICATE"
  assert_output_contains "END CERTIFICATE"
}

@test "trust export: exports PEM format to file" {
  run_certmgr_silent trust bundle -n test-pem --ca testca1

  local output_file="$CERTMGR_DIR/exported.pem"
  run_certmgr trust export -n test-pem --format pem -o "$output_file"
  assert_success
  assert_file_exists "$output_file"
  grep -q "BEGIN CERTIFICATE" "$output_file"
}

@test "trust export: generates Ubuntu installer script" {
  run_certmgr_silent trust bundle -n test-ubuntu --ca testca1

  run_certmgr trust export -n test-ubuntu --format ubuntu -o "$CERTMGR_DIR/install.sh"
  assert_success
  assert_output_contains "Exported Ubuntu/Debian installer"
  assert_file_exists "$CERTMGR_DIR/install.sh"
  assert_file_exists "$CERTMGR_DIR/test-ubuntu.crt"

  # Verify script content
  grep -q "update-ca-certificates" "$CERTMGR_DIR/install.sh"
  grep -q "/usr/local/share/ca-certificates/" "$CERTMGR_DIR/install.sh"
  [[ -x "$CERTMGR_DIR/install.sh" ]]
}

@test "trust export: generates Debian installer script" {
  run_certmgr_silent trust bundle -n test-debian --ca testca1

  run_certmgr trust export -n test-debian --format debian -o "$CERTMGR_DIR/install.sh"
  assert_success
  assert_output_contains "Exported Ubuntu/Debian installer"
  grep -q "update-ca-certificates" "$CERTMGR_DIR/install.sh"
}

@test "trust export: generates RHEL installer script" {
  run_certmgr_silent trust bundle -n test-rhel --ca testca1

  run_certmgr trust export -n test-rhel --format rhel -o "$CERTMGR_DIR/install.sh"
  assert_success
  assert_output_contains "Exported RHEL/CentOS installer"
  assert_file_exists "$CERTMGR_DIR/install.sh"

  # Verify script content
  grep -q "update-ca-trust" "$CERTMGR_DIR/install.sh"
  grep -q "/etc/pki/ca-trust/source/anchors/" "$CERTMGR_DIR/install.sh"
}

@test "trust export: generates Alpine installer script" {
  run_certmgr_silent trust bundle -n test-alpine --ca testca1

  run_certmgr trust export -n test-alpine --format alpine -o "$CERTMGR_DIR/install.sh"
  assert_success
  assert_output_contains "Exported Alpine installer"
  assert_file_exists "$CERTMGR_DIR/install.sh"

  # Verify script content
  grep -q "update-ca-certificates" "$CERTMGR_DIR/install.sh"
  grep -q "/usr/local/share/ca-certificates/" "$CERTMGR_DIR/install.sh"
  grep -q '#!/usr/bin/env sh' "$CERTMGR_DIR/install.sh"
}

@test "trust export: generates Dockerfile snippets" {
  run_certmgr_silent trust bundle -n test-docker --ca testca1

  run_certmgr trust export -n test-docker --format dockerfile -o "$CERTMGR_DIR/Dockerfile.snippet"
  assert_success
  assert_output_contains "Exported Dockerfile snippets"
  assert_file_exists "$CERTMGR_DIR/Dockerfile.snippet"
  assert_file_exists "$CERTMGR_DIR/test-docker.crt"

  # Verify Dockerfile content
  grep -q "FROM alpine:latest" "$CERTMGR_DIR/Dockerfile.snippet"
  grep -q "FROM ubuntu:latest" "$CERTMGR_DIR/Dockerfile.snippet"
  grep -q "FROM centos:latest" "$CERTMGR_DIR/Dockerfile.snippet"
  grep -q "COPY test-docker.crt" "$CERTMGR_DIR/Dockerfile.snippet"
}

@test "trust export: generates Kubernetes ConfigMap" {
  run_certmgr_silent trust bundle -n test-k8s --ca testca1

  run_certmgr trust export -n test-k8s --format k8s -o "$CERTMGR_DIR/configmap.yaml"
  assert_success
  assert_output_contains "Exported Kubernetes ConfigMap"
  assert_output_contains "Usage in Pod:"
  assert_file_exists "$CERTMGR_DIR/configmap.yaml"

  # Verify ConfigMap content
  grep -q "apiVersion: v1" "$CERTMGR_DIR/configmap.yaml"
  grep -q "kind: ConfigMap" "$CERTMGR_DIR/configmap.yaml"
  grep -q "name: test-k8s-ca-bundle" "$CERTMGR_DIR/configmap.yaml"
  grep -q "ca-bundle.crt:" "$CERTMGR_DIR/configmap.yaml"
  grep -q "BEGIN CERTIFICATE" "$CERTMGR_DIR/configmap.yaml"
}

@test "trust export: k8s-configmap alias works" {
  run_certmgr_silent trust bundle -n test-k8s-alias --ca testca1

  run_certmgr trust export -n test-k8s-alias --format k8s-configmap
  assert_success
  assert_output_contains "apiVersion: v1"
  assert_output_contains "kind: ConfigMap"
}

@test "trust export: fails for non-existent bundle" {
  run_certmgr trust export -n nonexistent --format pem
  assert_failure
  assert_output_contains "Trust bundle 'nonexistent' not found"
}

@test "trust export: fails for invalid format" {
  run_certmgr_silent trust bundle -n test-invalid --ca testca1

  run_certmgr trust export -n test-invalid --format invalid-format
  assert_failure
  assert_output_contains "Unknown format"
  assert_output_contains "Supported formats:"
}

@test "trust export: requires bundle name" {
  run_certmgr trust export --format pem
  assert_failure
  assert_output_contains "Bundle name is required"
}

# Command aliases

@test "trust: 't' alias works" {
  run_certmgr t bundle -n alias-test --ca testca1
  assert_success
  assert_output_contains "Creating trust bundle 'alias-test'"

  run_certmgr t list
  assert_success
  assert_output_contains "alias-test"
}

@test "trust: 'create' alias for 'bundle' works" {
  run_certmgr trust create -n create-test --ca testca1
  assert_success
  assert_output_contains "Creating trust bundle 'create-test'"
}

@test "trust: 'ls' alias for 'list' works" {
  run_certmgr_silent trust bundle -n ls-test --ca testca1

  run_certmgr trust ls
  assert_success
  assert_output_contains "Trust Bundles"
  assert_output_contains "ls-test"
}

# Integration scenarios

@test "trust bundle: multi-CA bundle in real workflow" {
  # Create multiple CAs for different environments
  run_certmgr_silent ca create -n prod-ca --subject "/C=US/O=Prod/CN=Production CA"
  run_certmgr_silent ca create -n staging-ca --subject "/C=US/O=Staging/CN=Staging CA"
  run_certmgr_silent ca create -n dev-ca --subject "/C=US/O=Dev/CN=Development CA"

  # Create trust bundle for all environments
  run_certmgr trust bundle -n all-envs --ca prod-ca,staging-ca,dev-ca
  assert_success

  # Export for different platforms
  run_certmgr trust export -n all-envs --format ubuntu -o "$CERTMGR_DIR/install-ubuntu.sh"
  assert_success

  run_certmgr trust export -n all-envs --format k8s -o "$CERTMGR_DIR/k8s-bundle.yaml"
  assert_success

  # Verify all exports exist
  assert_file_exists "$CERTMGR_DIR/install-ubuntu.sh"
  assert_file_exists "$CERTMGR_DIR/k8s-bundle.yaml"
  assert_file_exists "$CERTMGR_DIR/all-envs.crt"
}

@test "trust bundle: validates certificate count in bundle" {
  run_certmgr_silent trust bundle -n count-test --ca testca1,testca2,testca3

  local bundle_file="$CERTMGR_DIR/trust/count-test/bundle.pem"
  local cert_count
  cert_count=$(grep -c "BEGIN CERTIFICATE" "$bundle_file")
  [[ $cert_count -eq 3 ]]
}

@test "trust bundle: metadata contains correct information" {
  run_certmgr_silent trust bundle -n metadata-test --ca testca1,testca2

  local metadata_file="$CERTMGR_DIR/trust/metadata-test/metadata.txt"
  assert_file_exists "$metadata_file"

  grep -q "CA: testca1" "$metadata_file"
  grep -q "CA: testca2" "$metadata_file"
  grep -q "Subject:.*Test CA 1" "$metadata_file"
  grep -q "Subject:.*Test CA 2" "$metadata_file"
  grep -q "File:.*testca1/ca.crt" "$metadata_file"
  grep -q "File:.*testca2/ca.crt" "$metadata_file"
}
