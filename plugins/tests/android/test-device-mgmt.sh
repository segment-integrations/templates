#!/usr/bin/env bash
set -euo pipefail

echo "Android Device Management Tests"
echo "================================"
echo ""

cd "$(dirname "$0")/../../examples/android" 2>/dev/null || {
  echo "Error: Android example directory not found"
  exit 1
}

# Source test framework
. "../../plugins/tests/test-framework.sh"

# Test 1: Device list command
echo "Test: Device listing..."
assert_command_success "Device list command succeeds" \
  bash -c "devbox run --pure android.sh devices list"

# Test 2: Device selection and lock file generation
echo "Test: Device selection..."
if devbox run --pure android.sh devices select max >/dev/null 2>&1; then
  assert_file_exists "devbox.d/android/devices.lock.json" "Lock file created after select"
else
  echo "✗ Device select command failed"
  ((TEST_FAIL++))
fi

# Test 3: Lock file structure
echo "Test: Lock file structure..."
if [ -f "devbox.d/android/devices.lock.json" ]; then
  api_versions=$(jq -r '.api_versions | length' devbox.d/android/devices.lock.json 2>/dev/null || echo "0")
  if [ "$api_versions" -gt 0 ]; then
    ((TEST_PASS++))
    echo "✓ Lock file contains API versions"
  else
    ((TEST_FAIL++))
    echo "✗ Lock file missing API versions"
  fi

  # Test 4: Checksum exists
  checksum=$(jq -r '.checksum // ""' devbox.d/android/devices.lock.json 2>/dev/null || echo "")
  if [ -n "$checksum" ]; then
    ((TEST_PASS++))
    echo "✓ Lock file contains checksum"
  else
    ((TEST_FAIL++))
    echo "✗ Lock file missing checksum"
  fi
else
  ((TEST_FAIL+=2))
  echo "✗ Lock file not found"
fi

# Test 5: Config commands
echo "Test: Config show command..."
assert_command_success "Config show succeeds" \
  bash -c "devbox run --pure android.sh config show"

test_summary
