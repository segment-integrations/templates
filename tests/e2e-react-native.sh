#!/usr/bin/env bash
set -euo pipefail

# This script is in tests/, examples are in examples/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/../examples/react-native"

echo "========================================="
echo "E2E Test: React Native Example"
echo "========================================="
echo ""

cd "$EXAMPLE_DIR"

echo "1/6 Installing Node dependencies..."
devbox run build:node

echo "2/6 Building web bundle..."
devbox run build:web

echo "3/6 Starting Android (builds, starts emulator, deploys app)..."
devbox run start:android

echo "4/6 Stopping Android emulator..."
devbox run stop:emu

echo "5/6 Starting iOS (builds, starts simulator, deploys app)..."
devbox run start:ios

echo "6/6 Stopping iOS simulator..."
devbox run stop:sim

echo ""
echo "✓ React Native example E2E test passed!"
