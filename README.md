# certmgr - Certificate Manager

A user-friendly command-line tool for managing Certificate Authorities (CAs) and issuing TLS/SSL certificates.

## Features

- 🔐 **Multi-CA Management** - Create and manage multiple Certificate Authorities
- 📜 **Easy Certificate Issuance** - Issue server certificates with auto-populated defaults
- 🎨 **Colorful CLI** - Beautiful, intuitive command-line interface
- ⚙️ **YAML Configuration** - Optional configuration file for defaults
- 🚀 **No Root Required** - Runs entirely in userspace
- 🔍 **Config Introspection** - See where each setting comes from
- 💾 **Persistent Storage** - Organized directory structure for all certificates
- 🎯 **Smart Defaults** - Auto-detect CN, SAN, and CA when possible
- 📊 **Human-Friendly Output** - Clear certificate summaries
- 🔒 **Trust Bundle Management** - Easy CA distribution for Ubuntu, RHEL, Alpine, K8s, containers

## Quick Start

```bash
# 1. Initialize storage
./certmgr init

# 2. Create a CA
./certmgr ca create -n myca

# 3. Issue a certificate (minimal)
./certmgr cert issue -n myserver

# 4. View certificate details
./certmgr cert show -n myserver

# 5. Create trust bundle and export for Ubuntu
./certmgr trust bundle -n all --ca all
./certmgr trust export -n all --format ubuntu -o install.sh

# 6. Check configuration
./certmgr config
```

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/certmgr.git
cd certmgr

# Make executable
chmod +x certmgr

# Install to /usr/local/bin
make install
```

### Requirements

- Bash 4.0+
- OpenSSL

## Usage

### Command Aliases

For faster workflows:

```bash
certmgr c new -n myca          # Create CA (short form)
certmgr c ls                   # List CAs
certmgr i -n server            # Issue certificate (short form)
certmgr cert ls                # List certificates
certmgr t bundle -n all --ca all  # Create trust bundle (short form)
certmgr t ls                   # List trust bundles
```

### Initialize

```bash
certmgr init
```

Creates the directory structure:
```
certs/
├── CAs/          # Certificate Authorities
├── issued/       # Issued certificates
└── trust/        # Trust bundles
```

### Certificate Authority Management

**Create a CA:**
```bash
# Minimal
certmgr ca create -n production-ca

# With custom subject
certmgr ca create -n myca \
  --subject "/C=US/O=Acme/CN=Acme Root CA" \
  --days 3650 \
  --key-bits 4096 \
  --digest sha384
```

**List CAs:**
```bash
certmgr ca list
```

**Show CA details:**
```bash
certmgr ca show -n production-ca
```

### Certificate Issuance

**Minimal (everything auto-detected):**
```bash
certmgr cert issue -n myserver
# Auto-detects: CN=myserver, SAN=myserver, uses only available CA
```

**With custom options:**
```bash
certmgr cert issue -n web01 \
  --cn web01.example.com \
  --san "web01.example.com,www.example.com,192.168.1.10" \
  --ca production-ca \
  --days 825
```

**List certificates:**
```bash
certmgr cert list
```

**Show certificate details:**
```bash
certmgr cert show -n web01
```

Output:
```
— Certificate Summary —

Name:      web01
CN:        web01.example.com
SANs:      web01.example.com,www.example.com,192.168.1.10
Issuer:    production-ca Root CA
Validity:  2025-01-01 → 2027-03-01

Files:
  Key:   certs/issued/web01/server.key
  Cert:  certs/issued/web01/server.crt
  Chain: certs/issued/web01/chain.crt
```

### Trust Bundle Management

Trust bundles make it easy to distribute your CAs to systems, containers, and Kubernetes clusters.

**Create a trust bundle with all CAs:**
```bash
certmgr trust bundle -n all-cas --ca all
```

**Create a trust bundle with specific CAs:**
```bash
certmgr trust bundle -n prod-staging --ca production-ca,staging-ca
```

**List trust bundles:**
```bash
certmgr trust list
```

**Show bundle details:**
```bash
certmgr trust show -n all-cas
```

**Export for different platforms:**

```bash
# PEM format (universal)
certmgr trust export -n all-cas --format pem -o ca-bundle.pem

# Ubuntu/Debian installation script
certmgr trust export -n all-cas --format ubuntu -o install-ubuntu.sh
chmod +x install-ubuntu.sh
sudo ./install-ubuntu.sh

# RHEL/CentOS/Fedora installation script
certmgr trust export -n all-cas --format rhel -o install-rhel.sh

# Alpine Linux installation script
certmgr trust export -n all-cas --format alpine -o install-alpine.sh

# Dockerfile snippets for containers
certmgr trust export -n all-cas --format dockerfile -o Dockerfile.ca

# Kubernetes ConfigMap
certmgr trust export -n all-cas --format k8s -o ca-bundle-configmap.yaml
kubectl apply -f ca-bundle-configmap.yaml
```

**Use in Kubernetes Pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  volumes:
  - name: ca-bundle
    configMap:
      name: all-cas-ca-bundle
  containers:
  - name: myapp
    image: myapp:latest
    volumeMounts:
    - name: ca-bundle
      mountPath: /etc/ssl/certs/ca-bundle.crt
      subPath: ca-bundle.crt
```

**Use in Dockerfile:**
```dockerfile
FROM ubuntu:latest
COPY all-cas.crt /usr/local/share/ca-certificates/
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates
```

### Configuration

**View current configuration:**
```bash
certmgr config
```

Shows configuration with source attribution:
- `[default]` - Built-in defaults
- `[yaml:key]` - From YAML config file
- `[env:VAR]` - From environment variable

**Environment Variables:**
```bash
export CERTMGR_DIR=/custom/path/certs
export CERTMGR_CONFIG=/path/to/config.yaml
export OPENSSL_BIN=/custom/openssl
```

**YAML Configuration (`certmgr.yaml`):**
```yaml
base_dir: /opt/certificates
openssl_bin: /usr/bin/openssl

cas:
  production:
    subject: "/C=US/O=Acme/CN=Acme Production Root"
    days: 3650
    key_bits: 4096
    digest: sha256

  staging:
    subject: "/C=US/O=Acme/CN=Acme Staging Root"
    days: 1825
    key_bits: 2048
    digest: sha256
```

## Testing

Comprehensive BATS test suite with 60+ test cases:

```bash
# Run all tests
make test

# Run specific suite
make test-ca          # CA operations
make test-cert        # Certificate issuance
make test-aliases     # Command aliases
make test-config      # Config introspection
make test-e2e         # End-to-end workflows

# View coverage
make test-coverage

# CI pipeline
make ci
```

See [tests/README.md](tests/README.md) for detailed testing documentation.

## Demos

```bash
# Basic workflow demonstration
make demo-basic

# Command aliases demonstration
make demo-aliases

# Multi-CA environment
make demo-multi-ca
```

## Development

```bash
# Check script syntax
make check

# Lint with shellcheck
make lint

# Run all checks
make test-all

# View all make targets
make help
```

## Directory Structure

```
certmgr/
├── certmgr              # Main script
├── Makefile             # Build and test automation
├── README.md            # This file
├── certmgr.yaml         # Optional configuration (user-created)
├── certs/               # Certificate storage (created by init)
│   ├── CAs/            # Certificate Authorities
│   │   └── myca/
│   │       ├── ca.crt
│   │       ├── private.key
│   │       ├── serial.txt
│   │       └── index.txt
│   └── issued/         # Issued certificates
│       └── myserver/
│           ├── server.key
│           ├── server.csr
│           ├── server.crt
│           ├── chain.crt
│           └── openssl.cnf
└── tests/              # BATS test suite
    ├── test_helper.bash
    ├── 01_init.bats
    ├── 02_ca_operations.bats
    ├── 03_cert_issuance.bats
    ├── 04_aliases.bats
    ├── 05_config_introspection.bats
    ├── 06_human_friendly_output.bats
    ├── 07_e2e_workflows.bats
    ├── fixtures/
    │   ├── basic-config.yaml
    │   ├── minimal-config.yaml
    │   ├── advanced-config.yaml
    │   └── custom-openssl.yaml
    └── README.md
```

## Examples

### Basic Workflow
```bash
certmgr init
certmgr ca create -n myca
certmgr cert issue -n server01
certmgr cert show -n server01
```

### Multi-CA Environment
```bash
certmgr init
certmgr ca create -n prod-ca --subject "/C=US/O=Prod/CN=Prod Root"
certmgr ca create -n dev-ca --subject "/C=US/O=Dev/CN=Dev Root"

certmgr cert issue -n prod-web --ca prod-ca --cn web.prod.com
certmgr cert issue -n dev-test --ca dev-ca --cn test.dev.local

certmgr ca list
certmgr cert list
```

### Using Aliases
```bash
certmgr c new -n quick-ca
certmgr i -n quick-server
certmgr c ls
certmgr cert ls
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Ensure `make ci` passes
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- Report issues: [GitHub Issues](https://github.com/yourusername/certmgr/issues)
- Documentation: This README and `tests/README.md`
- Run `certmgr help` for command reference

## Roadmap

- [ ] Certificate renewal workflow
- [ ] CRL (Certificate Revocation List) support
- [ ] OCSP responder setup
- [ ] Intermediate CA support
- [ ] Client certificate issuance
- [ ] Bulk certificate operations
- [ ] Integration with popular web servers
- [ ] Docker container support
# certmgr
# certmgr
