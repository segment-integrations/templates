#!/usr/bin/env bash
# Test script to determine if included plugins' init hooks run automatically

set -e

cd "$(dirname "$0")/examples/react-native"

echo "=== Test: Do included plugins' init hooks run automatically? ==="
echo ""

# Clean slate
echo "Step 1: Removing .devbox directory..."
rm -rf .devbox
echo "✓ Cleaned"
echo ""

# Initialize shell
echo "Step 2: Running 'devbox shell' to trigger init hooks..."
devbox shell -- bash -c 'echo "Shell initialized"' > /dev/null 2>&1
echo "✓ Shell initialized"
echo ""

# Check results
echo "Step 3: Checking what files were created..."
echo ""

echo "Android virtenv:"
if [ -f ".devbox/virtenv/android/android.json" ]; then
  echo "  ✅ android.json exists (android-init.sh RAN)"
else
  echo "  ❌ android.json missing (android-init.sh DID NOT RUN)"
fi

if [ -f ".devbox/virtenv/android/devices.lock.json" ]; then
  echo "  ✅ devices.lock.json exists"
else
  echo "  ❌ devices.lock.json missing"
fi

echo ""
echo "iOS virtenv:"
if [ -f ".devbox/virtenv/ios/ios.json" ]; then
  echo "  ✅ ios.json exists (ios-init.sh RAN)"
else
  echo "  ❌ ios.json missing (ios-init.sh DID NOT RUN)"
fi

echo ""
echo "React Native virtenv:"
ls -1 .devbox/virtenv/react-native/ 2>/dev/null | sed 's/^/  - /' || echo "  (empty or doesn't exist)"

echo ""
echo "=== Conclusion ==="
if [ -f ".devbox/virtenv/android/android.json" ] && [ -f ".devbox/virtenv/ios/ios.json" ]; then
  echo "✅ SCENARIO A: Included plugins' init hooks DO run automatically"
  echo ""
  echo "This means:"
  echo "  - Android and iOS init hooks run automatically"
  echo "  - devices.lock files are generated automatically"
  echo "  - React Native env.sh is REDUNDANT (but harmless)"
  echo "  - We could simplify by removing RN init_hook entirely"
else
  echo "❌ SCENARIO B: Included plugins' init hooks DON'T run automatically"
  echo ""
  echo "This means:"
  echo "  - Only RN init_hook runs"
  echo "  - RN env.sh sourcing android/ios env.sh is CRITICAL"
  echo "  - Current setup is necessary"
fi
