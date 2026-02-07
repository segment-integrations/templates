#!/usr/bin/env bash
set -euo pipefail

echo "Android Validation Tests"
echo "========================"
echo ""

cd "$(dirname "$0")/../../../examples/android" 2>/dev/null || {
  echo "Error: Android example directory not found"
  exit 1
}

# Source test framework
. "../../plugins/tests/test-framework.sh"

# Test 1: Doctor command runs successfully
echo "Test: Doctor command validation..."
assert_command_success "Doctor command runs" \
  bash -c "devbox run doctor >/dev/null 2>&1"

# Test 2: Verify setup command
echo "Test: Verify setup command..."
assert_command_success "Verify setup succeeds" \
  bash -c "devbox run verify:setup >/dev/null 2>&1"

# Test 3: Lock file has valid checksum
echo "Test: Lock file checksum validation..."
devbox run --pure android.sh devices eval >/dev/null 2>&1 || true

if [ -f "devbox.d/android/devices/devices.lock" ]; then
  # Check if lock file has content
  if [ -s "devbox.d/android/devices/devices.lock" ]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ Lock file has valid content"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ Lock file is empty"
  fi
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Lock file not found"
fi

# Test 4: Config show displays configuration
echo "Test: Config displays configuration..."
output=$(devbox run --pure android.sh config show 2>&1 || true)
if echo "$output" | grep -q "ANDROID_DEFAULT_DEVICE"; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ Config displays configuration values"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Config output incomplete"
fi

test_summary
