#!/usr/bin/env bash
# Android Plugin - Validation Functions
# See SCRIPTS.md for detailed documentation
# Philosophy: Warn, don't block

set -euo pipefail

# Validate that devices.lock.json matches current device definitions (non-blocking)
android_validate_lock_file() {
  # Local variables (not user-facing)
  lock_file_path="${ANDROID_CONFIG_DIR}/devices.lock.json"
  devices_directory="${ANDROID_DEVICES_DIR}"

  # Check if lock file exists (it's optional, so no warning if missing)
  if [ ! -f "$lock_file_path" ]; then
    return 0
  fi

  # Ensure lib.sh is loaded for checksum function
  if ! command -v android_compute_devices_checksum >/dev/null 2>&1; then
    # lib.sh not loaded, skip validation
    return 0
  fi

  # Compute current checksum using shared utility function
  current_checksum="$(android_compute_devices_checksum "$devices_directory" 2>/dev/null || true)"

  if [ -z "$current_checksum" ]; then
    # No checksum tool available or directory issue, skip validation
    return 0
  fi

  # Read checksum from lock file
  lock_file_checksum="$(jq -r '.checksum // ""' "$lock_file_path" 2>/dev/null || echo "")"

  # Compare checksums
  if [ "$current_checksum" != "$lock_file_checksum" ]; then
    echo "WARNING: devices.lock.json may be stale (device definitions changed)" >&2
    echo "         Run 'devbox run android.sh devices eval' to update" >&2
  fi

  return 0
}

# Validate that ANDROID_SDK_ROOT points to an existing directory (non-blocking)
android_validate_sdk() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "WARNING: ANDROID_SDK_ROOT points to non-existent directory: $ANDROID_SDK_ROOT" >&2
  fi

  return 0
}
