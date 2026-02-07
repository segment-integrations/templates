#!/usr/bin/env bash
# Android Plugin - devices.sh Integration Tests

set -euo pipefail

test_passed=0
test_failed=0

assert_success() {
  if eval "$1" >/dev/null 2>&1; then
    echo "  ✓ PASS: $2"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: $2"
    test_failed=$((test_failed + 1))
  fi
}

echo "========================================"
echo "Android devices.sh Integration Tests"
echo "========================================"
echo ""

# Setup test environment
test_root="/tmp/android-plugin-device-test-$$"
mkdir -p "$test_root/devices"
mkdir -p "$test_root/scripts"

# Copy required scripts
script_dir="$(cd "$(dirname "$0")" && pwd)"
cp "$script_dir/../../android/scripts/lib.sh" "$test_root/scripts/"
cp "$script_dir/../../android/scripts/env.sh" "$test_root/scripts/"
cp "$script_dir/../../android/scripts/devices.sh" "$test_root/scripts/"

# Set environment variables (new config approach)
export ANDROID_CONFIG_DIR="$test_root"
export ANDROID_DEVICES_DIR="$test_root/devices"
export ANDROID_SCRIPTS_DIR="$test_root/scripts"
export ANDROID_DEVICES=""  # Empty = all devices
export ANDROID_DEFAULT_DEVICE=""

devices_script="$test_root/scripts/devices.sh"

# Test: Create device
echo "TEST: Create device"
assert_success "$devices_script create test_pixel --api 28 --device pixel --tag google_apis" "Create device"
assert_success "[ -f '$test_root/devices/test_pixel.json' ]" "Device file created"

# Test: List devices
echo ""
echo "TEST: List devices"
assert_success "$devices_script list | grep -q test_pixel" "List shows created device"

# Test: Show device
echo ""
echo "TEST: Show device"
assert_success "$devices_script show test_pixel | grep -q '\"api\": 28'" "Show device contains correct API"

# Test: Update device
echo ""
echo "TEST: Update device"
assert_success "$devices_script update test_pixel --api 34" "Update device API"
assert_success "$devices_script show test_pixel | grep -q '\"api\": 34'" "Device updated correctly"

# Test: Eval (generate lock file) - with specific device selected
echo ""
echo "TEST: Generate lock file with device selection"
export ANDROID_DEVICES="test_pixel"
assert_success "$devices_script eval" "Generate lock file"
assert_success "[ -f '$test_root/devices/devices.lock' ]" "Lock file created"
assert_success "grep -q 'test_pixel' '$test_root/devices/devices.lock'" "Lock file contains device name"
assert_success "grep -q '34' '$test_root/devices/devices.lock'" "Lock file contains API 34"

# Test: Delete device
echo ""
echo "TEST: Delete device"
assert_success "$devices_script delete test_pixel" "Delete device"
assert_success "[ ! -f '$test_root/devices/test_pixel.json' ]" "Device file removed"

# Cleanup
rm -rf "$test_root"

# Summary
echo ""
echo "========================================"
total=$((test_passed + test_failed))
echo "Total:  $total"
echo "Passed: $test_passed"
echo "Failed: $test_failed"
echo ""

if [ "$test_failed" -gt 0 ]; then
  echo "RESULT: ✗ FAILED"
  exit 1
else
  echo "RESULT: ✓ ALL PASSED"
  exit 0
fi
