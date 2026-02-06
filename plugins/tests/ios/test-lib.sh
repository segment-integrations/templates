#!/usr/bin/env sh
set -eu

echo "Testing iOS lib.sh..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_SCRIPTS_DIR="${SCRIPT_DIR}/../../ios/scripts"
export IOS_SCRIPTS_DIR

# Source lib.sh
. "${IOS_SCRIPTS_DIR}/lib.sh"

# Test 1: Load-once guard
echo "  Test 1: Load-once guard"
. "${IOS_SCRIPTS_DIR}/lib.sh"
if [ "${IOS_LIB_LOADED}" != "1" ]; then
  echo "    FAIL: Load-once guard failed"
  exit 1
fi
echo "    PASS"

# Test 2: Execution protection
echo "  Test 2: Execution protection"
if sh "${IOS_SCRIPTS_DIR}/lib.sh" 2>/dev/null; then
  echo "    FAIL: Execution protection failed"
  exit 1
fi
echo "    PASS"

# Test 3: ios_sanitize_device_name
echo "  Test 3: ios_sanitize_device_name"
result="$(ios_sanitize_device_name "iPhone 15 Pro" || true)"
if [ "$result" != "iPhone 15 Pro" ]; then
  echo "    FAIL: Expected 'iPhone 15 Pro', got '$result'"
  exit 1
fi
result="$(ios_sanitize_device_name "Test Device!@#" || true)"
if [ "$result" != "Test Device" ]; then
  echo "    FAIL: Expected 'Test Device', got '$result'"
  exit 1
fi
echo "    PASS"

# Test 4: ios_config_path fallback
echo "  Test 4: ios_config_path"
unset IOS_CONFIG_DIR
DEVBOX_PROJECT_ROOT="${SCRIPT_DIR}/../../.."
export DEVBOX_PROJECT_ROOT
if ! config_path="$(ios_config_path 2>/dev/null)"; then
  echo "    SKIP: No config found (expected in test environment)"
else
  if [ ! -f "$config_path" ]; then
    echo "    FAIL: config_path returned non-existent file: $config_path"
    exit 1
  fi
  echo "    PASS"
fi

# Test 5: ios_devices_dir fallback
echo "  Test 5: ios_devices_dir"
unset IOS_DEVICES_DIR
if ! devices_dir="$(ios_devices_dir 2>/dev/null)"; then
  echo "    SKIP: No devices dir found (expected in test environment)"
else
  if [ ! -d "$devices_dir" ]; then
    echo "    FAIL: devices_dir returned non-existent directory: $devices_dir"
    exit 1
  fi
  echo "    PASS"
fi

# Test 6: ios_compute_devices_checksum
echo "  Test 6: ios_compute_devices_checksum"
if devices_dir="$(ios_devices_dir 2>/dev/null)"; then
  checksum="$(ios_compute_devices_checksum "$devices_dir" || true)"
  if [ -z "$checksum" ]; then
    echo "    FAIL: Checksum computation failed"
    exit 1
  fi
  if [ "${#checksum}" -ne 64 ]; then
    echo "    FAIL: Checksum length is not 64 characters: ${#checksum}"
    exit 1
  fi
  echo "    PASS"
else
  echo "    SKIP: No devices dir found"
fi

# Test 7: ios_require_jq
echo "  Test 7: ios_require_jq"
if command -v jq >/dev/null 2>&1; then
  ios_require_jq
  echo "    PASS"
else
  echo "    SKIP: jq not available"
fi

# Test 8: ios_require_tool
echo "  Test 8: ios_require_tool"
ios_require_tool "sh" "sh is required" || { echo "    FAIL"; exit 1; }
if (ios_require_tool "nonexistent_tool_xyz" 2>/dev/null); then
  echo "    FAIL: Should have failed for nonexistent tool"
  exit 1
fi
echo "    PASS"

echo "All lib.sh tests passed!"
