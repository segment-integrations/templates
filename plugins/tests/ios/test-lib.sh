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

# Create temporary test directory structure
test_root="/tmp/ios-plugin-test-$$"
mkdir -p "$test_root/devbox.d/ios/devices"

# Create test device files
cat > "$test_root/devbox.d/ios/devices/test1.json" <<'EOF'
{
  "name": "iPhone 15 Pro",
  "runtime": "17.5"
}
EOF

cat > "$test_root/devbox.d/ios/devices/test2.json" <<'EOF'
{
  "name": "iPhone 16",
  "runtime": "18.0"
}
EOF

# Test 4: ios_config_path
echo "  Test 4: ios_config_path"
unset IOS_CONFIG_DIR
DEVBOX_PROJECT_ROOT="$test_root"
export DEVBOX_PROJECT_ROOT
config_path="$(ios_config_path 2>/dev/null || true)"
if [ -z "$config_path" ]; then
  echo "    FAIL: ios_config_path returned empty"
  rm -rf "$test_root"
  exit 1
fi
expected="$test_root/devbox.d/ios"
if [ "$config_path" != "$expected" ]; then
  echo "    FAIL: Expected '$expected', got '$config_path'"
  rm -rf "$test_root"
  exit 1
fi
echo "    PASS"

# Test 5: ios_devices_dir
echo "  Test 5: ios_devices_dir"
unset IOS_DEVICES_DIR
devices_dir="$(ios_devices_dir 2>/dev/null || true)"
if [ -z "$devices_dir" ]; then
  echo "    FAIL: ios_devices_dir returned empty"
  rm -rf "$test_root"
  exit 1
fi
expected="$test_root/devbox.d/ios/devices"
if [ "$devices_dir" != "$expected" ]; then
  echo "    FAIL: Expected '$expected', got '$devices_dir'"
  rm -rf "$test_root"
  exit 1
fi
if [ ! -d "$devices_dir" ]; then
  echo "    FAIL: devices_dir doesn't exist: $devices_dir"
  rm -rf "$test_root"
  exit 1
fi
echo "    PASS"

# Test 6: ios_compute_devices_checksum
echo "  Test 6: ios_compute_devices_checksum"
checksum1="$(ios_compute_devices_checksum "$devices_dir" || true)"
if [ -z "$checksum1" ]; then
  echo "    FAIL: Checksum computation failed"
  rm -rf "$test_root"
  exit 1
fi
if [ "${#checksum1}" -ne 64 ]; then
  echo "    FAIL: Checksum length is not 64 characters: ${#checksum1}"
  rm -rf "$test_root"
  exit 1
fi
# Test checksum stability
checksum2="$(ios_compute_devices_checksum "$devices_dir" || true)"
if [ "$checksum1" != "$checksum2" ]; then
  echo "    FAIL: Checksum not stable - got different results"
  rm -rf "$test_root"
  exit 1
fi
echo "    PASS"

# Cleanup test directory
rm -rf "$test_root"

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
