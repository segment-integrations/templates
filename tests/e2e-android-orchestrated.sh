#!/usr/bin/env bash
set -euo pipefail

# Orchestrated E2E test for Android using process-compose

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/../examples/android"

echo "========================================="
echo "E2E Test: Android (Orchestrated)"
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
export ANDROID_APP_ID="${ANDROID_APP_ID:-com.example.devbox}"

# Run the orchestrated test
echo "Starting orchestrated Android E2E test..."
echo "This will:"
echo "  1. Setup AVD (if needed)"
echo "  2. Build Android app (parallel)"
echo "  3. Start emulator and wait for boot"
echo "  4. Deploy app to emulator"
echo "  5. Verify app is running"
echo ""

# Run process-compose with the test configuration
# Use --tui=false for CI environments, --tui=true for interactive
TUI_MODE="${TEST_TUI:-false}"

if process-compose -f "$SCRIPT_DIR/process-compose-android.yaml" \
    --tui="$TUI_MODE" \
    --ordered-shutdown \
    --keep-tui; then
    echo ""
    echo "✓ Android orchestrated E2E test passed!"
    exit 0
else
    echo ""
    echo "✗ Android orchestrated E2E test failed!"
    echo "Check logs at: /tmp/android-e2e-logs"
    exit 1
fi
