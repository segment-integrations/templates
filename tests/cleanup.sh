#!/usr/bin/env bash
# Manual cleanup script to kill all test-related processes

echo "🧹 Cleaning up all test processes..."
echo ""

# Kill process-compose
echo "Killing process-compose..."
pkill -9 process-compose 2>/dev/null && echo "  ✓ Killed process-compose" || echo "  - No process-compose running"

# Kill Android emulators
echo "Killing Android emulators..."
pkill -9 qemu-system 2>/dev/null && echo "  ✓ Killed emulators" || echo "  - No emulators running"
pkill -9 emulator 2>/dev/null || true

# Kill adb
echo "Killing adb server..."
if command -v adb >/dev/null 2>&1; then
  adb kill-server 2>/dev/null && echo "  ✓ Killed adb server" || echo "  - adb already stopped"
else
  pkill -9 adb 2>/dev/null && echo "  ✓ Killed adb" || echo "  - No adb running"
fi

# Kill iOS simulators
if command -v xcrun >/dev/null 2>&1; then
  echo "Shutting down iOS simulators..."
  xcrun simctl shutdown all 2>/dev/null && echo "  ✓ Shutdown simulators" || echo "  - No simulators running"
  pkill -9 Simulator 2>/dev/null || true
fi

# Kill any devbox processes that might be hanging
echo "Cleaning up devbox processes..."
pkill -9 -f "devbox run" 2>/dev/null && echo "  ✓ Killed devbox processes" || echo "  - No devbox processes"

echo ""
echo "✓ Cleanup complete!"
echo ""
echo "To verify everything is cleaned up:"
echo "  ps aux | grep -E 'process-compose|emulator|adb|Simulator' | grep -v grep"
