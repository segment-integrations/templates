#!/usr/bin/env bash
# Check if devbox environment is initialized and cached

echo "Checking devbox environment initialization status..."
echo ""

check_example() {
  local name="$1"
  local path="$2"

  echo "📦 $name:"

  if [ ! -d "$path/.devbox" ]; then
    echo "  ❌ Not initialized (.devbox directory missing)"
    echo "     Run: cd $path && devbox shell"
    return 1
  fi

  # Note: Nix handles flake evaluation caching internally - no need to check for cache files

  # Check for iOS cache
  if [ "$name" = "iOS" ] || [ "$name" = "React Native (iOS)" ]; then
    if [ -f "$path/.devbox/virtenv/ios/.xcode_dev_dir.cache" ]; then
      echo "  ✓ Xcode path cache exists"
    else
      echo "  ⏳ Xcode path NOT cached"
    fi
  fi

  echo "  ✓ Initialized"
  echo ""
}

check_example "Android" "examples/android"
check_example "iOS" "examples/ios"
check_example "React Native" "examples/react-native"

echo "💡 To pre-initialize and cache everything:"
echo "   cd examples/android && devbox shell -- echo 'Ready'"
echo "   cd examples/ios && devbox shell -- echo 'Ready'"
echo "   cd examples/react-native && devbox shell -- echo 'Ready'"
echo ""
echo "After initialization, tests will be much faster!"
