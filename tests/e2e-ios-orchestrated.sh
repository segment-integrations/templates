#!/usr/bin/env bash
set -euo pipefail

# Orchestrated E2E test for iOS using process-compose

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

echo "========================================="
echo "E2E Test: iOS (Orchestrated)"
echo "========================================="
echo ""

cd "$REPO_ROOT"

# Track test exit status
TEST_EXIT_STATUS=0

# Cleanup function to kill all child processes
cleanup() {
  local exit_code=$?
  # Use saved exit status if available, otherwise use the exit code from the trap
  if [ "$TEST_EXIT_STATUS" -ne 0 ]; then
    exit_code=$TEST_EXIT_STATUS
  fi

  echo ""
  echo "🧹 Cleaning up processes..."

  # Kill all process-compose instances
  pkill -P $$ process-compose 2>/dev/null || true
  pkill -9 process-compose 2>/dev/null || true

  # Kill any simulators started by this script
  pkill -P $$ Simulator 2>/dev/null || true

  # Shutdown all simulators
  xcrun simctl shutdown all 2>/dev/null || true

  echo "✓ Cleanup complete"

  # Exit with the correct status
  exit $exit_code
}

# Set trap to cleanup on exit, interrupt, or termination
trap cleanup EXIT INT TERM

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
    --no-server --keep-project; then
    echo ""
    echo "✓ iOS orchestrated E2E test passed!"
    TEST_EXIT_STATUS=0
else
    echo ""
    echo "✗ iOS orchestrated E2E test failed!"
    echo "Check logs at: test-results/ios-repo-e2e-logs"
    TEST_EXIT_STATUS=1
fi

# Don't exit here - let the trap handle it with cleanup
exit $TEST_EXIT_STATUS
