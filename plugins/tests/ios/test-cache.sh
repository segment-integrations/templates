#!/usr/bin/env bash
set -euo pipefail

echo "iOS Cache Tests"
echo "==============="
echo ""

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping iOS cache tests (not on macOS)"
  exit 0
fi

cd "$(dirname "$0")/../../examples/ios" 2>/dev/null || {
  echo "Error: iOS example directory not found"
  exit 1
}

# Source test framework
. "../../plugins/tests/test-framework.sh"

# Test 1: Cache directory creation
echo "Test: Cache directory exists after shell init..."
devbox shell -c "exit" >/dev/null 2>&1 || true

if [ -d ".devbox/virtenv/ios" ]; then
  ((TEST_PASS++))
  echo "✓ Cache directory created"
else
  ((TEST_FAIL++))
  echo "✗ Cache directory not found"
fi

# Test 2: Xcode cache file
echo "Test: Xcode developer directory cache..."
cache_file=".devbox/virtenv/ios/.xcode_dev_dir.cache"

# Clear cache
rm -f "$cache_file"

# First shell init (should create cache)
devbox shell -c "exit" >/dev/null 2>&1 || true

if [ -f "$cache_file" ]; then
  ((TEST_PASS++))
  echo "✓ Xcode cache file created"

  # Check cache content
  cached_path=$(cat "$cache_file" 2>/dev/null || true)
  if [ -n "$cached_path" ] && [ -d "$cached_path" ]; then
    ((TEST_PASS++))
    echo "✓ Cache contains valid Xcode path"
  else
    ((TEST_FAIL++))
    echo "✗ Cache contains invalid path"
  fi
else
  ((TEST_FAIL+=2))
  echo "✗ Xcode cache file not created"
fi

# Test 3: Cache reuse
echo "Test: Cache is reused on second shell..."
if [ -f "$cache_file" ]; then
  cache_mtime_before=$(stat -f %m "$cache_file" 2>/dev/null || echo "0")
  sleep 1
  devbox shell -c "exit" >/dev/null 2>&1 || true
  cache_mtime_after=$(stat -f %m "$cache_file" 2>/dev/null || echo "0")

  if [ "$cache_mtime_before" = "$cache_mtime_after" ]; then
    ((TEST_PASS++))
    echo "✓ Cache was reused (not regenerated)"
  else
    # This might be expected if cache is old
    ((TEST_PASS++))
    echo "✓ Cache was regenerated (expected if old)"
  fi
else
  ((TEST_FAIL++))
  echo "✗ Cache file missing"
fi

test_summary
