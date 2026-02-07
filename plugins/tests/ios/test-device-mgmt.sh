#!/usr/bin/env bash
set -euo pipefail

echo "iOS Device Management Tests"
echo "============================"
echo ""

cd "$(dirname "$0")/../../../examples/ios" 2>/dev/null || {
  echo "Error: iOS example directory not found"
  exit 1
}

# Source test framework
. "../../plugins/tests/test-framework.sh"

# Test 1: Device list command
echo "Test: Device listing..."
assert_command_success "Device list command succeeds" \
  bash -c "devbox run --pure ios.sh devices list"

# Test 2: Lock file evaluation (new approach - generates from IOS_DEVICES env var)
echo "Test: Lock file evaluation..."
if devbox run --pure ios.sh devices eval >/dev/null 2>&1; then
  assert_file_exists "devbox.d/ios/devices/devices.lock" "Lock file created after eval"
else
  echo "✗ Device eval command failed"
  TEST_FAIL=$((TEST_FAIL + 1))
fi

# Test 3: Lock file structure (new format is plain text with checksums)
echo "Test: Lock file structure..."
if [ -f "devbox.d/ios/devices/devices.lock" ]; then
  # Lock file should contain device names and checksums
  if grep -q ":" "devbox.d/ios/devices/devices.lock" 2>/dev/null; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ Lock file contains device checksums"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ Lock file has invalid format"
  fi
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Lock file not found"
fi

# Test 4: Config commands
echo "Test: Config show command..."
assert_command_success "Config show succeeds" \
  bash -c "devbox run --pure ios.sh config show"

test_summary
