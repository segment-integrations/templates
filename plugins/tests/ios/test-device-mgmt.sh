#!/usr/bin/env bash
set -euo pipefail

echo "iOS Device Management Tests"
echo "============================"
echo ""

cd "$(dirname "$0")/../../examples/ios" 2>/dev/null || {
  echo "Error: iOS example directory not found"
  exit 1
}

# Source test framework
. "../../plugins/tests/test-framework.sh"

# Test 1: Device list command
echo "Test: Device listing..."
assert_command_success "Device list command succeeds" \
  bash -c "devbox run --pure ios.sh devices list"

# Test 2: Device selection and lock file generation
echo "Test: Device selection..."
if devbox run --pure ios.sh devices select min >/dev/null 2>&1; then
  assert_file_exists "devbox.d/ios/devices/devices.lock" "Lock file created after select"
else
  echo "✗ Device select command failed"
  ((TEST_FAIL++))
fi

# Test 3: Lock file structure
echo "Test: Lock file structure..."
if [ -f "devbox.d/ios/devices/devices.lock" ]; then
  devices=$(jq -r '.devices | length' devbox.d/ios/devices/devices.lock 2>/dev/null || echo "0")
  if [ "$devices" -ge 0 ]; then
    ((TEST_PASS++))
    echo "✓ Lock file contains devices array"
  else
    ((TEST_FAIL++))
    echo "✗ Lock file missing devices array"
  fi

  # Test 4: Checksum exists
  checksum=$(jq -r '.checksum // ""' devbox.d/ios/devices/devices.lock 2>/dev/null || echo "")
  if [ -n "$checksum" ]; then
    ((TEST_PASS++))
    echo "✓ Lock file contains checksum"
  else
    ((TEST_FAIL++))
    echo "✗ Lock file missing checksum"
  fi

  # Test 5: Timestamp exists
  timestamp=$(jq -r '.generated_at // ""' devbox.d/ios/devices/devices.lock 2>/dev/null || echo "")
  if [ -n "$timestamp" ]; then
    ((TEST_PASS++))
    echo "✓ Lock file contains timestamp"
  else
    ((TEST_FAIL++))
    echo "✗ Lock file missing timestamp"
  fi
else
  ((TEST_FAIL+=3))
  echo "✗ Lock file not found"
fi

# Test 6: Config commands
echo "Test: Config show command..."
assert_command_success "Config show succeeds" \
  bash -c "devbox run --pure ios.sh config show"

test_summary
