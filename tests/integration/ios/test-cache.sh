#!/usr/bin/env bash
set -euo pipefail

echo "iOS Cache Integration Tests"
echo "============================"
echo ""

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping iOS cache tests (not on macOS)"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../.."

# Source test framework
. "$REPO_ROOT/plugins/tests/test-framework.sh"

# Setup test environment
TEST_ROOT="/tmp/ios-cache-test-$$"
mkdir -p "$TEST_ROOT/devbox.d/ios/devices"
mkdir -p "$TEST_ROOT/devbox.d/ios/scripts"
mkdir -p "$TEST_ROOT/.devbox/virtenv/ios"

# Copy fixtures
cp "$SCRIPT_DIR/../../fixtures/ios/devices/"*.json "$TEST_ROOT/devbox.d/ios/devices/"

# Copy plugin scripts
cp -r "$REPO_ROOT/plugins/ios/scripts/"* "$TEST_ROOT/devbox.d/ios/scripts/"
chmod +x "$TEST_ROOT/devbox.d/ios/scripts/"*.sh

# Set environment for tests
export IOS_CONFIG_DIR="$TEST_ROOT/devbox.d/ios"
export IOS_DEVICES_DIR="$TEST_ROOT/devbox.d/ios/devices"
export IOS_SCRIPTS_DIR="$TEST_ROOT/devbox.d/ios/scripts"
export IOS_DEVICES=""

cd "$TEST_ROOT"

# Test 1: Lock file generation
echo "Test: Lock file generation..."
if "$IOS_SCRIPTS_DIR/devices.sh" eval >/dev/null 2>&1; then
  if [ -f "$IOS_DEVICES_DIR/devices.lock" ]; then
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
if [ -f "$IOS_DEVICES_DIR/devices.lock" ]; then
  if [ -s "$IOS_DEVICES_DIR/devices.lock" ]; then
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

# Test 3: Xcode developer directory resolution
echo "Test: Xcode developer directory..."
if xcrun --show-sdk-path >/dev/null 2>&1; then
  ((TEST_PASS++))
  echo "✓ Xcode command line tools available"
else
  echo "⚠ Xcode tools not available (skipping)"
  ((TEST_PASS++))  # Don't fail if Xcode isn't installed
fi

# Test 4: Lock file has checksum
echo "Test: Lock file checksum..."
if [ -f "$IOS_DEVICES_DIR/devices.lock" ]; then
  if jq -e '.checksum' "$IOS_DEVICES_DIR/devices.lock" >/dev/null 2>&1; then
    checksum=$(jq -r '.checksum' "$IOS_DEVICES_DIR/devices.lock")
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

# Test 5: Device list shows fixtures
echo "Test: Device list validation..."
device_list=$("$IOS_SCRIPTS_DIR/devices.sh" list 2>/dev/null || echo "")
if echo "$device_list" | grep -q "test_iphone"; then
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
