#!/usr/bin/env bash
set -euo pipefail

echo "Android Validation Integration Tests"
echo "====================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../.."

# Source test framework
. "$REPO_ROOT/plugins/tests/test-framework.sh"

# Setup test environment
TEST_ROOT="/tmp/android-validation-test-$$"
mkdir -p "$TEST_ROOT/devbox.d/android/devices"
mkdir -p "$TEST_ROOT/devbox.d/android/scripts"

# Copy fixtures
cp "$SCRIPT_DIR/../../fixtures/android/devices/"*.json "$TEST_ROOT/devbox.d/android/devices/"

# Copy plugin scripts
cp -r "$REPO_ROOT/plugins/android/scripts/"* "$TEST_ROOT/devbox.d/android/scripts/"
chmod +x "$TEST_ROOT/devbox.d/android/scripts/"*.sh

# Set environment for tests
export ANDROID_CONFIG_DIR="$TEST_ROOT/devbox.d/android"
export ANDROID_DEVICES_DIR="$TEST_ROOT/devbox.d/android/devices"
export ANDROID_SCRIPTS_DIR="$TEST_ROOT/devbox.d/android/scripts"
export ANDROID_DEVICES=""
export ANDROID_SDK_ROOT="/tmp/fake-sdk"
export ANDROID_DEFAULT_DEVICE="test_pixel_api36"

cd "$TEST_ROOT"

# Test 1: Lock file generation
echo "Test: Lock file generation..."
if sh "$ANDROID_SCRIPTS_DIR/devices.sh" eval >/dev/null 2>&1; then
  if [ -f "$ANDROID_DEVICES_DIR/devices.lock" ]; then
    ((TEST_PASS++))
    echo "✓ Lock file generated successfully"
  else
    ((TEST_FAIL++))
    echo "✗ Lock file not created"
  fi
else
  ((TEST_FAIL++))
  echo "✗ Device eval command failed"
fi

# Test 2: Lock file has valid content
echo "Test: Lock file content validation..."
if [ -f "$ANDROID_DEVICES_DIR/devices.lock" ]; then
  if [ -s "$ANDROID_DEVICES_DIR/devices.lock" ]; then
    ((TEST_PASS++))
    echo "✓ Lock file has valid content"
  else
    ((TEST_FAIL++))
    echo "✗ Lock file is empty"
  fi
else
  ((TEST_FAIL++))
  echo "✗ Lock file not found"
fi

# Test 3: Lock file has checksum
echo "Test: Lock file checksum..."
if [ -f "$ANDROID_DEVICES_DIR/devices.lock" ]; then
  if jq -e '.checksum' "$ANDROID_DEVICES_DIR/devices.lock" >/dev/null 2>&1; then
    checksum=$(jq -r '.checksum' "$ANDROID_DEVICES_DIR/devices.lock")
    if [ -n "$checksum" ] && [ "$checksum" != "null" ]; then
      ((TEST_PASS++))
      echo "✓ Lock file has valid checksum"
    else
      ((TEST_FAIL++))
      echo "✗ Lock file checksum is invalid"
    fi
  else
    ((TEST_FAIL++))
    echo "✗ Lock file missing checksum field"
  fi
else
  ((TEST_FAIL++))
  echo "✗ Lock file not found"
fi

# Test 4: Device list shows fixtures
echo "Test: Device list validation..."
device_list=$(sh "$ANDROID_SCRIPTS_DIR/devices.sh" list 2>/dev/null || echo "")
if echo "$device_list" | grep -q "test_pixel"; then
  ((TEST_PASS++))
  echo "✓ Device list shows test devices"
else
  ((TEST_FAIL++))
  echo "✗ Device list doesn't show expected devices"
fi

# Cleanup
cd /
rm -rf "$TEST_ROOT"

test_summary
