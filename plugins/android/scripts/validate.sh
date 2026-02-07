#!/usr/bin/env bash
# Android Plugin - Validation Functions
# See SCRIPTS.md for detailed documentation
# Philosophy: Warn, don't block

set -euo pipefail

# Validate that ANDROID_SDK_ROOT points to an existing directory (non-blocking)
android_validate_sdk() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "WARNING: ANDROID_SDK_ROOT points to non-existent directory: $ANDROID_SDK_ROOT" >&2
  fi

  return 0
}
