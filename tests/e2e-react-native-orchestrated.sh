#!/usr/bin/env bash
set -euo pipefail

# Orchestrated E2E test for React Native using process-compose

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/../examples/react-native"

echo "========================================="
echo "E2E Test: React Native (Orchestrated)"
echo "========================================="
echo ""

cd "$EXAMPLE_DIR"

# Ensure we have process-compose
if ! command -v process-compose &> /dev/null; then
    echo "Error: process-compose not found. Installing..."
    devbox add process-compose
fi

# Export required environment variables
export ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
export IOS_DEVICE="${IOS_DEFAULT_DEVICE:-max}"

# Run the orchestrated test
echo "Starting orchestrated React Native E2E test..."
echo "This will:"
echo "  1. Install Node dependencies"
echo "  2. Build web bundle"
echo "  3. Test Android workflow (setup → build → emulator → deploy → verify)"
echo "  4. Test iOS workflow (verify → build → simulator → deploy → verify)"
echo ""
echo "Note: Android and iOS tests run sequentially (not in parallel) to avoid resource conflicts"
echo ""

# Run process-compose with the test configuration
TUI_MODE="${TEST_TUI:-false}"

if process-compose -f "$SCRIPT_DIR/process-compose-react-native.yaml" \
    --tui="$TUI_MODE" \
    --ordered-shutdown \
    --keep-tui; then
    echo ""
    echo "✓ React Native orchestrated E2E test passed!"
    exit 0
else
    echo ""
    echo "✗ React Native orchestrated E2E test failed!"
    echo "Check logs at: /tmp/rn-e2e-logs"
    exit 1
fi
