#!/usr/bin/env bash
set -euo pipefail

# Orchestrated E2E test for iOS using process-compose

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/../examples/ios"

echo "========================================="
echo "E2E Test: iOS (Orchestrated)"
echo "========================================="
echo ""

cd "$EXAMPLE_DIR"

# Ensure we have process-compose
if ! command -v process-compose &> /dev/null; then
    echo "Error: process-compose not found. Installing..."
    devbox add process-compose
fi

# Export required environment variables
export IOS_DEVICE="${IOS_DEFAULT_DEVICE:-max}"
export IOS_APP_BUNDLE_ID="${IOS_APP_BUNDLE_ID:-com.example.ios}"

# Run the orchestrated test
echo "Starting orchestrated iOS E2E test..."
echo "This will:"
echo "  1. Verify simulator exists"
echo "  2. Build iOS app (parallel)"
echo "  3. Start simulator and wait for boot"
echo "  4. Deploy app to simulator"
echo "  5. Verify app is running"
echo ""

# Run process-compose with the test configuration
TUI_MODE="${TEST_TUI:-false}"

if process-compose -f "$SCRIPT_DIR/process-compose-ios.yaml" \
    --tui="$TUI_MODE" \
    --ordered-shutdown \
    --keep-tui; then
    echo ""
    echo "✓ iOS orchestrated E2E test passed!"
    exit 0
else
    echo ""
    echo "✗ iOS orchestrated E2E test failed!"
    echo "Check logs at: /tmp/ios-e2e-logs"
    exit 1
fi
