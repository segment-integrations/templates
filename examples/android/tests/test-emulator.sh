#!/usr/bin/env bash
#
# Example: Test that the Android emulator starts correctly
# Copy this to your own project and customize as needed
#

set -euo pipefail

echo "========================================="
echo "Test: Android Emulator"
echo "========================================="
echo ""

# Start emulator in background
echo "Starting Android emulator..."
android_start_emulator &
EMU_PID=$!

# Wait for boot
echo "Waiting for emulator to boot (max 2 minutes)..."
timeout 120 bash -c 'until adb wait-for-device shell "getprop sys.boot_completed" | grep -q 1; do sleep 2; done' || {
    echo "✗ Emulator failed to boot in time"
    kill $EMU_PID 2>/dev/null || true
    exit 1
}

echo "✓ Emulator started successfully"

# Check device is connected
if adb devices | grep -q emulator; then
    echo "✓ Device is connected"
    adb devices
else
    echo "✗ Device not found"
    android_stop_emulator
    exit 1
fi

# Cleanup
echo ""
echo "Stopping emulator..."
android_stop_emulator

echo ""
echo "✓ Emulator test passed"
