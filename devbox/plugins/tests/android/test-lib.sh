#!/usr/bin/env bash
# Android Plugin - lib.sh Unit Tests
#
# Tests for core utility functions in lib.sh

set -euo pipefail

# ============================================================================
# Test Framework
# ============================================================================

test_passed=0
test_failed=0
test_name=""

start_test() {
  test_name="$1"
  echo ""
  echo "TEST: $test_name"
}

assert_equal() {
  expected="$1"
  actual="$2"
  message="${3:-}"

  if [ "$expected" = "$actual" ]; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    Expected: '$expected'"
    echo "    Actual:   '$actual'"
    test_failed=$((test_failed + 1))
  fi
}

assert_success() {
  command_str="$1"
  message="${2:-}"

  if eval "$command_str" >/dev/null 2>&1; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    Command failed: $command_str"
    test_failed=$((test_failed + 1))
  fi
}

assert_failure() {
  command_str="$1"
  message="${2:-}"

  # Run in subshell to prevent exit from killing test script
  if ! (eval "$command_str") >/dev/null 2>&1; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    Command should have failed: $command_str"
    test_failed=$((test_failed + 1))
  fi
}

test_summary() {
  total=$((test_passed + test_failed))
  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
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
}

# ============================================================================
# Setup
# ============================================================================

script_dir="$(cd "$(dirname "$0")" && pwd)"
lib_path="$script_dir/../../android/scripts/lib.sh"

if [ ! -f "$lib_path" ]; then
  echo "ERROR: lib.sh not found at: $lib_path"
  exit 1
fi

# Source lib.sh
. "$lib_path"

echo "========================================"
echo "Android lib.sh Unit Tests"
echo "========================================"
echo "Testing: $lib_path"

# ============================================================================
# Tests: String Normalization
# ============================================================================

start_test "android_normalize_name - lowercase conversion"
result="$(android_normalize_name "Pixel")"
assert_equal "pixel" "$result" "Should convert to lowercase"

start_test "android_normalize_name - removes special chars"
result="$(android_normalize_name "Pixel-8_Pro")"
assert_equal "pixel8pro" "$result" "Should remove dashes and underscores"

start_test "android_normalize_name - removes spaces"
result="$(android_normalize_name "Nexus 5X")"
assert_equal "nexus5x" "$result" "Should remove spaces"

start_test "android_sanitize_avd_name - preserves allowed chars"
result="$(android_sanitize_avd_name "Pixel_8-Pro.v2")"
assert_equal "Pixel_8-Pro.v2" "$result" "Should preserve ._- characters"

start_test "android_sanitize_avd_name - converts spaces"
result="$(android_sanitize_avd_name "Pixel 8 Pro")"
assert_equal "Pixel_8_Pro" "$result" "Should convert spaces to underscores"

start_test "android_sanitize_avd_name - removes invalid chars"
result="$(android_sanitize_avd_name "Pixel@#8!")"
assert_equal "Pixel8" "$result" "Should remove @#! characters"

start_test "android_sanitize_avd_name - fails on empty input"
assert_failure "android_sanitize_avd_name ''" "Should fail on empty string"

# ============================================================================
# Tests: Checksum Functions
# ============================================================================

# Create temporary test directory with device files
test_dir="/tmp/android-plugin-test-$$"
mkdir -p "$test_dir"
echo '{"name":"test1","api":28}' > "$test_dir/test1.json"
echo '{"name":"test2","api":34}' > "$test_dir/test2.json"

start_test "android_compute_devices_checksum - generates checksum"
result="$(android_compute_devices_checksum "$test_dir")"
assert_success "[ -n '$result' ]" "Should return non-empty checksum"

start_test "android_compute_devices_checksum - stable checksum"
checksum1="$(android_compute_devices_checksum "$test_dir")"
checksum2="$(android_compute_devices_checksum "$test_dir")"
assert_equal "$checksum1" "$checksum2" "Should return same checksum for same files"

start_test "android_compute_devices_checksum - different content = different checksum"
checksum_before="$(android_compute_devices_checksum "$test_dir")"
echo '{"name":"test3","api":36}' > "$test_dir/test3.json"
checksum_after="$(android_compute_devices_checksum "$test_dir")"
assert_success "[ '$checksum_before' != '$checksum_after' ]" "Should change when files change"

# Cleanup
rm -rf "$test_dir"

start_test "android_compute_devices_checksum - fails on non-existent dir"
assert_failure "android_compute_devices_checksum '/nonexistent/path'" "Should fail on missing directory"

# ============================================================================
# Tests: Path Resolution
# ============================================================================

# Create test directory structure
test_root="/tmp/android-plugin-path-test-$$"
mkdir -p "$test_root/devbox.d/android/devices"
echo '{"test":"data"}' > "$test_root/devbox.d/android/android.json"

start_test "android_resolve_project_path - finds existing file"
export DEVBOX_PROJECT_ROOT="$test_root"
result="$(android_resolve_project_path "android.json")"
assert_equal "$test_root/devbox.d/android/android.json" "$result" "Should resolve to correct path"

start_test "android_resolve_project_path - finds directory"
result="$(android_resolve_project_path "devices")"
assert_equal "$test_root/devbox.d/android/devices" "$result" "Should resolve devices directory"

start_test "android_resolve_project_path - fails on missing path"
assert_failure "android_resolve_project_path 'nonexistent.json'" "Should fail when path doesn't exist"

start_test "android_resolve_config_dir - finds config directory"
result="$(android_resolve_config_dir)"
assert_equal "$test_root/devbox.d/android" "$result" "Should find android config directory"

# Cleanup
unset DEVBOX_PROJECT_ROOT
rm -rf "$test_root"

# ============================================================================
# Tests: Requirement Functions
# ============================================================================

start_test "android_require_jq - succeeds when jq available"
assert_success "android_require_jq" "Should succeed if jq is installed"

start_test "android_require_tool - succeeds for existing tool"
assert_success "android_require_tool 'sh'" "Should succeed for sh"

start_test "android_require_tool - fails for missing tool"
assert_failure "android_require_tool 'nonexistent_tool_xyz'" "Should fail for missing tool"

# Create test directory for dir_contains test
test_sdk="/tmp/android-sdk-test-$$"
mkdir -p "$test_sdk/platform-tools"

start_test "android_require_dir_contains - succeeds when path exists"
assert_success "android_require_dir_contains '$test_sdk' 'platform-tools'" "Should succeed when subpath exists"

start_test "android_require_dir_contains - fails when path missing"
assert_failure "android_require_dir_contains '$test_sdk' 'nonexistent'" "Should fail when subpath missing"

# Cleanup
rm -rf "$test_sdk"

# ============================================================================
# Test Summary
# ============================================================================

test_summary
