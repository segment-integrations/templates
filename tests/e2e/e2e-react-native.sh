#!/usr/bin/env bash
set -euo pipefail

# Orchestrated E2E test for React Native using process-compose

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

echo "========================================="
echo "E2E Test: React Native (Orchestrated)"
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

  # Kill any emulators/simulators started by this script
  pkill -P $$ qemu-system 2>/dev/null || true
  pkill -P $$ emulator 2>/dev/null || true
  pkill -P $$ Simulator 2>/dev/null || true

  # Kill adb server
  adb kill-server 2>/dev/null || true

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
    --no-server --keep-project; then
    echo ""
    echo "✓ React Native orchestrated E2E test passed!"
    TEST_EXIT_STATUS=0
else
    echo ""
    echo "✗ React Native orchestrated E2E test failed!"
    echo "Check logs at: test-results/react-native-repo-e2e-logs"
    TEST_EXIT_STATUS=1
fi

# Don't exit here - let the trap handle it with cleanup
exit $TEST_EXIT_STATUS
