#!/usr/bin/env bash
set -euo pipefail

echo "Android Validation Tests"
echo "========================"
echo ""

cd "$(dirname "$0")/../../examples/android" 2>/dev/null || {
  echo "Error: Android example directory not found"
  exit 1
}

# Source test framework
. "../../plugins/tests/test-framework.sh"

# Test 1: Stale lock file warning
echo "Test: Validation warns about stale lock file..."

# Ensure lock file exists
devbox run --pure android.sh devices eval >/dev/null 2>&1 || true

# Add a temporary device to make lock file stale
echo '{"name":"temp_test","api":99,"device":"pixel"}' > devbox.d/android/devices/temp_test.json

# Run shell and capture warnings
output=$(devbox shell -c "exit" 2>&1 || true)

if echo "$output" | grep -q "stale"; then
  ((TEST_PASS++))
  echo "✓ Stale lock file warning appears"
else
  ((TEST_FAIL++))
  echo "✗ Stale lock file warning not shown"
  echo "  Output: $output"
fi

# Clean up
rm -f devbox.d/android/devices/temp_test.json

# Regenerate lock file
devbox run --pure android.sh devices eval >/dev/null 2>&1 || true

# Test 2: No warning after fixing
echo "Test: No warning after lock file regeneration..."
output=$(devbox shell -c "exit" 2>&1 || true)

if echo "$output" | grep -q "stale"; then
  ((TEST_FAIL++))
  echo "✗ Warning still appears after fix"
else
  ((TEST_PASS++))
  echo "✓ No warning after fixing lock file"
fi

test_summary
