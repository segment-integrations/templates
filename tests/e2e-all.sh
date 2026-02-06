#!/usr/bin/env bash
set -euo pipefail

# E2E test runner that tests all example apps
# - Android and iOS tests run concurrently
# - Within each platform, tests run sequentially to avoid emulator/simulator conflicts
# - React Native tests both platforms sequentially after standalone tests complete

# This script is in tests/, examples are in examples/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
ANDROID_RESULT=0
IOS_RESULT=0
REACT_NATIVE_RESULT=0

# Log files for parallel execution
ANDROID_LOG="/tmp/e2e-android-$$.log"
IOS_LOG="/tmp/e2e-ios-$$.log"
REACT_NATIVE_LOG="/tmp/e2e-react-native-$$.log"

# Cleanup function
cleanup() {
  rm -f "$ANDROID_LOG" "$IOS_LOG" "$REACT_NATIVE_LOG"
}
trap cleanup EXIT

# Print section header
print_header() {
  echo ""
  echo -e "${BLUE}=========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}=========================================${NC}"
  echo ""
}

# Print test result
print_result() {
  local name="$1"
  local result="$2"
  if [ "$result" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} $name: ${GREEN}PASSED${NC}"
  else
    echo -e "${RED}✗${NC} $name: ${RED}FAILED${NC}"
  fi
}

# Test Android example
test_android() {
  {
    echo "========================================="
    echo "E2E Test: Android Example"
    echo "========================================="
    echo ""

    cd "$SCRIPT_DIR/../examples/android"

    echo "1/2 Starting Android (builds, starts emulator, deploys app)..."
    if ! devbox run start:android 2>&1; then
      echo "ERROR: Failed to start Android app"
      devbox run stop:emu 2>&1 || true
      exit 1
    fi

    echo "2/2 Stopping emulator..."
    if ! devbox run stop:emu 2>&1; then
      echo "WARNING: Failed to stop Android emulator cleanly"
    fi

    echo ""
    echo "✓ Android example E2E test passed!"
  } > "$ANDROID_LOG" 2>&1
  return $?
}

# Test iOS example
test_ios() {
  {
    echo "========================================="
    echo "E2E Test: iOS Example"
    echo "========================================="
    echo ""

    cd "$SCRIPT_DIR/../examples/ios"

    echo "1/2 Starting iOS (builds, starts simulator, deploys app)..."
    if ! devbox run start:ios 2>&1; then
      echo "ERROR: Failed to start iOS app"
      devbox run stop:sim 2>&1 || true
      exit 1
    fi

    echo "2/2 Stopping simulator..."
    if ! devbox run stop:sim 2>&1; then
      echo "WARNING: Failed to stop iOS simulator cleanly"
    fi

    echo ""
    echo "✓ iOS example E2E test passed!"
  } > "$IOS_LOG" 2>&1
  return $?
}

# Test React Native example (both platforms)
test_react_native() {
  {
    echo "========================================="
    echo "E2E Test: React Native Example"
    echo "========================================="
    echo ""

    cd "$SCRIPT_DIR/../examples/react-native"

    echo "1/6 Installing Node dependencies..."
    if ! devbox run build:node 2>&1; then
      echo "ERROR: Failed to install Node dependencies"
      exit 1
    fi

    echo "2/6 Building web bundle..."
    if ! devbox run build:web 2>&1; then
      echo "ERROR: Failed to build web bundle"
      exit 1
    fi

    echo "3/6 Starting Android (builds, starts emulator, deploys app)..."
    if ! devbox run start:android 2>&1; then
      echo "ERROR: Failed to start Android app"
      devbox run stop:emu 2>&1 || true
      exit 1
    fi

    echo "4/6 Stopping Android emulator..."
    if ! devbox run stop:emu 2>&1; then
      echo "WARNING: Failed to stop Android emulator cleanly"
    fi

    echo "5/6 Starting iOS (builds, starts simulator, deploys app)..."
    if ! devbox run start:ios 2>&1; then
      echo "ERROR: Failed to start iOS app"
      devbox run stop:sim 2>&1 || true
      exit 1
    fi

    echo "6/6 Stopping iOS simulator..."
    if ! devbox run stop:sim 2>&1; then
      echo "WARNING: Failed to stop iOS simulator cleanly"
    fi

    echo ""
    echo "✓ React Native example E2E test passed!"
  } > "$REACT_NATIVE_LOG" 2>&1
  return $?
}

# Stream log file with prefix
stream_log() {
  local log_file="$1"
  local prefix="$2"
  local color="$3"

  if [ -f "$log_file" ]; then
    while IFS= read -r line; do
      echo -e "${color}[${prefix}]${NC} $line"
    done < "$log_file"
  fi
}

# Main execution
main() {
  print_header "Running E2E Tests for All Examples"
  echo "Strategy:"
  echo "  - Phase 1: Android + iOS tests run concurrently"
  echo "  - Phase 2: React Native tests both platforms sequentially"
  echo ""

  # Phase 1: Run Android and iOS tests in parallel
  print_header "Phase 1: Running Android and iOS Tests Concurrently"

  echo -e "${YELLOW}Starting Android test in background...${NC}"
  test_android &
  ANDROID_PID=$!

  echo -e "${YELLOW}Starting iOS test in background...${NC}"
  test_ios &
  IOS_PID=$!

  echo ""
  echo "Waiting for Android and iOS tests to complete..."
  echo ""

  # Wait for both to complete
  if wait $ANDROID_PID; then
    ANDROID_RESULT=0
  else
    ANDROID_RESULT=$?
  fi

  if wait $IOS_PID; then
    IOS_RESULT=0
  else
    IOS_RESULT=$?
  fi

  # Show results from phase 1
  echo ""
  print_header "Phase 1 Results"

  if [ -f "$ANDROID_LOG" ]; then
    echo "Android test output:"
    stream_log "$ANDROID_LOG" "ANDROID" "$BLUE"
    echo ""
  else
    echo -e "${RED}ERROR: Android log file not found${NC}"
  fi

  if [ -f "$IOS_LOG" ]; then
    echo "iOS test output:"
    stream_log "$IOS_LOG" "iOS" "$GREEN"
    echo ""
  else
    echo -e "${RED}ERROR: iOS log file not found${NC}"
  fi

  print_result "Android Example" "$ANDROID_RESULT"
  print_result "iOS Example" "$IOS_RESULT"

  # Check if phase 1 failed
  if [ "$ANDROID_RESULT" -ne 0 ] || [ "$IOS_RESULT" -ne 0 ]; then
    echo ""
    echo -e "${RED}Phase 1 failed. Skipping React Native tests.${NC}"
    print_header "Final Results"
    print_result "Android Example" "$ANDROID_RESULT"
    print_result "iOS Example" "$IOS_RESULT"
    print_result "React Native Example" "255"
    exit 1
  fi

  # Phase 2: Run React Native test (tests both platforms sequentially)
  print_header "Phase 2: Running React Native Test"
  echo "This test will exercise both Android and iOS sequentially..."
  echo ""

  test_react_native
  REACT_NATIVE_RESULT=$?

  # Show React Native results
  echo ""
  stream_log "$REACT_NATIVE_LOG" "REACT-NATIVE" "$YELLOW"
  echo ""

  # Final summary
  print_header "Final Results"
  print_result "Android Example" "$ANDROID_RESULT"
  print_result "iOS Example" "$IOS_RESULT"
  print_result "React Native Example" "$REACT_NATIVE_RESULT"

  echo ""
  if [ "$ANDROID_RESULT" -eq 0 ] && [ "$IOS_RESULT" -eq 0 ] && [ "$REACT_NATIVE_RESULT" -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✓ All E2E Tests Passed!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "Summary:"
    echo "  - Android example: build + emulator + deploy"
    echo "  - iOS example: build + simulator + deploy"
    echo "  - React Native example: build all + Android + iOS + web"
    exit 0
  else
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}✗ Some E2E Tests Failed${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
  fi
}

main "$@"
