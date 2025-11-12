#!/usr/bin/env bash

# Quick setup script for certmgr testing

set -euo pipefail

echo "🔧 Setting up certmgr test environment..."

# Check for BATS
if ! command -v bats >/dev/null 2>&1; then
  echo "❌ BATS not found. Please install it:"
  echo ""
  echo "  macOS:    brew install bats-core"
  echo "  Ubuntu:   apt-get install bats"
  echo "  npm:      npm install -g bats"
  echo ""
  exit 1
fi

echo "✓ BATS is installed"

# Check for OpenSSL
if ! command -v openssl >/dev/null 2>&1; then
  echo "❌ OpenSSL not found. Please install OpenSSL."
  exit 1
fi

echo "✓ OpenSSL is installed"

# Make certmgr executable
chmod +x certmgr
echo "✓ Made certmgr executable"

# Check bash syntax
if bash -n certmgr; then
  echo "✓ Script syntax is valid"
else
  echo "❌ Script has syntax errors"
  exit 1
fi

# Optional: shellcheck
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -x certmgr; then
    echo "✓ No linting issues"
  else
    echo "⚠️  Some linting issues found (non-fatal)"
  fi
else
  echo "ℹ️  shellcheck not installed (optional)"
fi

echo ""
echo "✅ Setup complete! You can now run:"
echo ""
echo "  make test          # Run all tests"
echo "  make test-quick    # Run quick smoke tests"
echo "  make help          # See all available commands"
echo ""
