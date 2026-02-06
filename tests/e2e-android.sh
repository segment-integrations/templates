#!/usr/bin/env bash
set -euo pipefail

# This script is in tests/, examples are in examples/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/../examples/android"

echo "========================================="
echo "E2E Test: Android Example"
echo "========================================="
echo ""

cd "$EXAMPLE_DIR"

echo "1/2 Starting Android (builds, starts emulator, deploys app)..."
devbox run start:android

echo "2/2 Stopping emulator..."
devbox run stop:emu

echo ""
echo "✓ Android example E2E test passed!"
