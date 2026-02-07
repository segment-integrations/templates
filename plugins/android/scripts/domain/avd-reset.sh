#!/usr/bin/env sh
# Android Plugin - AVD Reset and Cleanup Operations
# Extracted from avd.sh to eliminate circular dependencies

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: avd_reset.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_AVD_RESET_LOADED:-}" = "1" ] && [ "${ANDROID_AVD_RESET_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_AVD_RESET_LOADED=1
ANDROID_AVD_RESET_LOADED_PID="$$"

# Source dependencies (Layer 1 & 2 only)
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  if [ -f "${ANDROID_SCRIPTS_DIR}/lib/lib.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
  fi
  if [ -f "${ANDROID_SCRIPTS_DIR}/platform/core.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/platform/core.sh"
  fi
  if [ -f "${ANDROID_SCRIPTS_DIR}/platform/device_config.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/platform/device_config.sh"
  fi
fi

# ============================================================================
# Path Safety Functions
# ============================================================================

# Resolve absolute path for safety checks
android_resolve_absolute_path() {
  target_path="$1"

  # If path is a directory, cd into it and get pwd
  if [ -d "$target_path" ]; then
    (cd "$target_path" 2>/dev/null && pwd)
    return $?
  fi

  # If path is a file, resolve directory and append filename
  if [ -e "$target_path" ]; then
    target_dir="$(cd "$(dirname "$target_path")" 2>/dev/null && pwd)" || return 1
    target_file="$(basename "$target_path")"
    printf '%s/%s\n' "$target_dir" "$target_file"
    return 0
  fi

  return 1
}

# Check if a path is within a safe root directory
android_is_safe_path() {
  candidate_path="$1"
  safe_root="$2"

  # Resolve to absolute path
  resolved_path="$(android_resolve_absolute_path "$candidate_path" 2>/dev/null || true)"
  if [ -z "$resolved_path" ]; then
    return 1
  fi

  # Check if resolved path starts with safe root
  case "$resolved_path" in
    "$safe_root"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Safely remove a directory (validates path is within safe_root)
android_safe_remove_directory() {
  target_dir="$1"
  safe_root="$2"

  # If doesn't exist, nothing to do
  if [ ! -e "$target_dir" ]; then
    return 0
  fi

  # Validate path is safe
  if ! android_is_safe_path "$target_dir" "$safe_root"; then
    echo "ERROR: Refusing to remove non-project path: $target_dir" >&2
    return 1
  fi

  # Determine rm binary (prefer system rm on macOS)
  rm_binary="rm"
  if [ "$(uname -s)" = "Darwin" ] && [ -x /bin/rm ]; then
    rm_binary="/bin/rm"
  fi

  # Remove macOS immutable flags if on macOS
  if command -v chflags >/dev/null 2>&1; then
    chflags -R nouchg "$target_dir" >/dev/null 2>&1 || true
  fi

  # Ensure we have write permissions
  chmod -R u+w "$target_dir" >/dev/null 2>&1 || true

  # Remove the directory
  if ! "$rm_binary" -rf "$target_dir"; then
    echo "ERROR: Failed to remove $target_dir" >&2
    echo "       Check permissions or Full Disk Access for your terminal" >&2
    return 1
  fi

  return 0
}

# Safely remove a file (validates path is within safe_root)
android_safe_remove_file() {
  target_file="$1"
  safe_root="$2"

  # If doesn't exist, nothing to do
  if [ ! -e "$target_file" ]; then
    return 0
  fi

  # Validate path is safe
  if ! android_is_safe_path "$target_file" "$safe_root"; then
    echo "ERROR: Refusing to remove non-project file: $target_file" >&2
    return 1
  fi

  # Determine rm binary
  rm_binary="rm"
  if [ "$(uname -s)" = "Darwin" ] && [ -x /bin/rm ]; then
    rm_binary="/bin/rm"
  fi

  # Remove the file
  if ! "$rm_binary" -f "$target_file"; then
    echo "ERROR: Failed to remove $target_file" >&2
    echo "       Check permissions" >&2
    return 1
  fi

  return 0
}

# ============================================================================
# AVD Reset
# ============================================================================

# Reset Android plugin state (AVDs, configs, adb keys)
android_reset_avds() {
  device_filter="${1:-}"

  echo "================================================"
  echo "Android AVD Reset"
  echo "================================================"
  echo ""

  # ---- Validate Environment ----

  sdk_home="${ANDROID_SDK_HOME:-}"
  if [ -z "$sdk_home" ]; then
    echo "ERROR: ANDROID_SDK_HOME is not set" >&2
    echo "       Cannot reset state without knowing Android state directory" >&2
    echo "       This safety check prevents accidental system-wide deletion" >&2
    return 1
  fi

  echo "Android state directory: $sdk_home"

  # ---- Determine Safe Root ----

  safe_root="$(android_resolve_absolute_path "$sdk_home/.." 2>/dev/null || true)"
  if [ -z "$safe_root" ]; then
    echo "ERROR: Unable to resolve Android state root directory" >&2
    echo "       Refusing to reset for safety" >&2
    return 1
  fi

  echo "Safe root: $safe_root"
  echo "  (Only paths within this directory will be removed)"
  echo ""

  # ---- Device-Specific or Full Reset ----

  if [ -n "$device_filter" ]; then
    # Reset specific device(s)
    echo "Resetting specific device: $device_filter"
    echo ""

    # Find device file
    devices_dir="$(android_get_devices_dir 2>/dev/null || true)"
    if [ -z "$devices_dir" ]; then
      echo "ERROR: Cannot find devices directory" >&2
      return 1
    fi

    device_file="$(android_resolve_device_file "$device_filter" "$devices_dir" 2>/dev/null || true)"
    if [ -z "$device_file" ]; then
      echo "ERROR: Device not found: $device_filter" >&2
      return 1
    fi

    # Get AVD name from device definition
    avd_name="$(jq -r '.name // empty' "$device_file")"
    if [ -z "$avd_name" ]; then
      echo "ERROR: Device definition has no name field: $device_file" >&2
      return 1
    fi

    # Delete the AVD
    android_delete_avd "$avd_name"
  else
    # Full reset - all AVDs and state
    echo "Resetting ALL Android state..."
    echo ""

    avd_directory="${ANDROID_AVD_HOME:-$sdk_home/avd}"
    android_dot_dir="$sdk_home/.android"
    adb_key_sdk="$sdk_home/adbkey"
    adb_key_sdk_pub="$sdk_home/adbkey.pub"
    adb_key_android="$android_dot_dir/adbkey"
    adb_key_android_pub="$android_dot_dir/adbkey.pub"

    echo "Will remove:"
    echo "  - AVDs: $avd_directory"
    echo "  - Android config: $android_dot_dir"
    echo "  - ADB keys: $adb_key_sdk, $adb_key_sdk_pub"
    echo "  - ADB keys: $adb_key_android, $adb_key_android_pub"
    echo ""

    # Remove AVD directory
    if [ -d "$avd_directory" ]; then
      echo "Removing AVDs..."
      android_safe_remove_directory "$avd_directory" "$safe_root"
      echo "  ✓ AVDs removed"
    else
      echo "  • AVDs directory not found (already clean)"
    fi

    # Remove .android directory
    if [ -d "$android_dot_dir" ]; then
      echo "Removing .android config..."
      android_safe_remove_directory "$android_dot_dir" "$safe_root"
      echo "  ✓ .android removed"
    else
      echo "  • .android directory not found (already clean)"
    fi

    # Remove ADB keys
    echo "Removing ADB keys..."
    android_safe_remove_file "$adb_key_sdk" "$safe_root"
    android_safe_remove_file "$adb_key_sdk_pub" "$safe_root"
    android_safe_remove_file "$adb_key_android" "$safe_root"
    android_safe_remove_file "$adb_key_android_pub" "$safe_root"
    echo "  ✓ ADB keys removed"
  fi

  echo ""
  echo "================================================"
  echo "✓ Reset complete!"
  echo "================================================"
  echo ""
  echo "To recreate AVDs, run:"
  echo "  devbox run start-emu [device]"
}

android_debug_log_script "avd_reset.sh"
