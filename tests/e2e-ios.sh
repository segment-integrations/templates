#!/usr/bin/env bash
set -euo pipefail

# This script is in tests/, examples are in examples/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/../examples/ios"

echo "========================================="
echo "E2E Test: iOS Example"
echo "========================================="
echo ""

cd "$EXAMPLE_DIR"

echo "1/2 Starting iOS (builds, starts simulator, deploys app)..."
devbox run start:ios

echo "2/2 Stopping simulator..."
devbox run stop:sim

echo ""
echo "✓ iOS example E2E test passed!"
