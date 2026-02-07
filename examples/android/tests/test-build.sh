#!/usr/bin/env bash
#
# Example: Test that your Android app builds successfully
# Copy this to your own project and customize as needed
#

set -euo pipefail

echo "========================================="
echo "Test: Android App Build"
echo "========================================="
echo ""

# Build the app
echo "Building Android app..."
gradle assembleDebug

# Verify APK exists
APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK_PATH" ]; then
    echo "✓ APK found: $APK_PATH"
    ls -lh "$APK_PATH"
else
    echo "✗ APK not found: $APK_PATH"
    exit 1
fi

echo ""
echo "✓ Build test passed"
