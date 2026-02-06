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
mkdir -p "$test_root/devbox.d/android/devices"
mkdir -p "$test_root/devbox.d/android/scripts"

# Copy required scripts
script_dir="$(cd "$(dirname "$0")" && pwd)"
cp "$script_dir/../../android/scripts/lib.sh" "$test_root/devbox.d/android/scripts/"
cp "$script_dir/../../android/scripts/devices.sh" "$test_root/devbox.d/android/scripts/"

# Create minimal config
cat > "$test_root/devbox.d/android/android.json" <<'EOF'
{
  "ANDROID_DEFAULT_DEVICE": "",
  "EVALUATE_DEVICES": []
}
EOF

export ANDROID_CONFIG_DIR="$test_root/devbox.d/android"
export ANDROID_SCRIPTS_DIR="$test_root/devbox.d/android/scripts"

devices_script="$test_root/devbox.d/android/scripts/devices.sh"

# Test: Create device
echo "TEST: Create device"
assert_success "$devices_script create test_pixel --api 28 --device pixel --tag google_apis" "Create device"
assert_success "[ -f '$test_root/devbox.d/android/devices/test_pixel.json' ]" "Device file created"

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

# Test: Select devices
echo ""
echo "TEST: Select device"
assert_success "$devices_script select test_pixel" "Select device"
assert_success "jq -e '.devices[] | select(.name == \"test_pixel\")' '$test_root/devbox.d/android/devices.lock.json' >/dev/null" "Device recorded in lock file"

# Test: Eval (generate lock file)
echo ""
echo "TEST: Generate lock file"
assert_success "$devices_script eval" "Generate lock file"
assert_success "[ -f '$test_root/devbox.d/android/devices.lock.json' ]" "Lock file created"
assert_success "grep -q '34' '$test_root/devbox.d/android/devices.lock.json'" "Lock file contains API 34"

# Test: Delete device
echo ""
echo "TEST: Delete device"
assert_success "$devices_script delete test_pixel" "Delete device"
assert_success "[ ! -f '$test_root/devbox.d/android/devices/test_pixel.json' ]" "Device file removed"

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
