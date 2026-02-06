#!/usr/bin/env bash
set -euo pipefail

# Calculate script directory (this script is in tests/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "Running E2E tests for all examples"
echo "Tests run sequentially with live output"
echo "========================================="
echo ""

echo "1/3 Testing Android example..."
echo ""
bash "$SCRIPT_DIR/e2e-android.sh"
ANDROID_RESULT=$?

echo ""
echo "2/3 Testing iOS example..."
echo ""
bash "$SCRIPT_DIR/e2e-ios.sh"
IOS_RESULT=$?

echo ""
echo "3/3 Testing React Native example..."
echo ""
bash "$SCRIPT_DIR/e2e-react-native.sh"
RN_RESULT=$?

echo ""
echo "========================================="
echo "Test Results Summary"
echo "========================================="

if [ $ANDROID_RESULT -eq 0 ]; then
  echo "✓ Android: PASSED"
else
  echo "✗ Android: FAILED (exit code: $ANDROID_RESULT)"
fi

if [ $IOS_RESULT -eq 0 ]; then
  echo "✓ iOS: PASSED"
else
  echo "✗ iOS: FAILED (exit code: $IOS_RESULT)"
fi

if [ $RN_RESULT -eq 0 ]; then
  echo "✓ React Native: PASSED"
else
  echo "✗ React Native: FAILED (exit code: $RN_RESULT)"
fi

echo ""

if [ $ANDROID_RESULT -eq 0 ] && [ $IOS_RESULT -eq 0 ] && [ $RN_RESULT -eq 0 ]; then
  echo "========================================="
  echo "✓ All E2E tests passed!"
  echo "========================================="
  exit 0
else
  echo "========================================="
  echo "✗ Some E2E tests failed"
  echo "========================================="
  exit 1
fi
