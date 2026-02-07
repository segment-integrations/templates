#!/usr/bin/env sh
# Android Plugin - Device Configuration Management
# Extracted from avd.sh to eliminate circular dependencies

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: device_config.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_DEVICE_CONFIG_LOADED:-}" = "1" ] && [ "${ANDROID_DEVICE_CONFIG_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_DEVICE_CONFIG_LOADED=1
ANDROID_DEVICE_CONFIG_LOADED_PID="$$"

# Source dependencies
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  if [ -f "${ANDROID_SCRIPTS_DIR}/lib.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/lib.sh"
  fi
  if [ -f "${ANDROID_SCRIPTS_DIR}/core.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/core.sh"
  fi
fi

# ============================================================================
# Device Files and Selection
# ============================================================================

# Get path to devices directory
android_get_devices_dir() {
  # Priority 1: Explicit ANDROID_DEVICES_DIR
  if [ -n "${ANDROID_DEVICES_DIR:-}" ] && [ -d "${ANDROID_DEVICES_DIR}" ]; then
    printf '%s\n' "${ANDROID_DEVICES_DIR}"
    return 0
  fi

  # Try using shared utility if available
  if command -v android_resolve_project_path >/dev/null 2>&1; then
    devices_path="$(android_resolve_project_path "devices" 2>/dev/null || true)"
    if [ -n "$devices_path" ] && [ -d "$devices_path" ]; then
      printf '%s\n' "$devices_path"
      return 0
    fi
  fi

  # Fallback: Check config dir directly
  if [ -n "${ANDROID_CONFIG_DIR:-}" ] && [ -d "${ANDROID_CONFIG_DIR}/devices" ]; then
    printf '%s\n' "${ANDROID_CONFIG_DIR}/devices"
    return 0
  fi

  return 1
}

# List all device definition files in directory
android_list_device_files() {
  devices_dir="$1"

  if [ -z "$devices_dir" ] || [ ! -d "$devices_dir" ]; then
    return 1
  fi

  find "$devices_dir" -type f -name '*.json' | sort
}

# Resolve device name to device file path
android_resolve_device_file() {
  device_selection="$1"
  devices_dir="$2"

  if [ -z "$device_selection" ] || [ -z "$devices_dir" ]; then
    return 1
  fi

  # Strategy 1: Try direct filename match
  candidate_file="${devices_dir}/${device_selection}.json"
  if [ -f "$candidate_file" ]; then
    printf '%s\n' "$candidate_file"
    return 0
  fi

  # Strategy 2: Search by .name field
  for device_file in $(android_list_device_files "$devices_dir"); do
    device_name="$(jq -r '.name // empty' "$device_file" 2>/dev/null || true)"
    if [ "$device_name" = "$device_selection" ]; then
      printf '%s\n' "$device_file"
      return 0
    fi
  done

  return 1
}

# Select device files based on user selection (or all if none specified)
android_select_device_files() {
  devices_dir="$1"

  # Determine which device(s) to process
  # Priority: ANDROID_DEVICE_NAME > TARGET_DEVICE > ANDROID_DEFAULT_DEVICE > all devices
  device_selection="${ANDROID_DEVICE_NAME:-${TARGET_DEVICE:-${ANDROID_DEFAULT_DEVICE:-}}}"

  if [ -n "$device_selection" ]; then
    # Try to find specific device
    device_file="$(android_resolve_device_file "$device_selection" "$devices_dir" 2>/dev/null || true)"
    if [ -n "$device_file" ]; then
      printf '%s\n' "$device_file"
      return 0
    fi

    echo "WARNING: Android device '$device_selection' not found in ${devices_dir}" >&2
    echo "         Using all available devices instead" >&2
  fi

  # Return all device files
  android_list_device_files "$devices_dir"
}

android_debug_log_script "device_config.sh"
