#!/usr/bin/env bash
set -euo pipefail

TEST_PASS=0
TEST_FAIL=0

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  if [ "$expected" = "$actual" ]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File exists: $file}"

  if [ -f "$file" ]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local message="${3:-File contains pattern: $pattern}"

  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
  fi
}

assert_command_success() {
  local message="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
    echo "  Command failed: $*"
  fi
}

test_summary() {
  echo ""
  echo "===================================="
  echo "Test Results:"
  echo "  Passed: $TEST_PASS"
  echo "  Failed: $TEST_FAIL"
  echo "===================================="

  if [ "$TEST_FAIL" -gt 0 ]; then
    exit 1
  fi
}
