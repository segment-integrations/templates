#!/usr/bin/env sh
# iOS Plugin - Device Configuration Management
# Extracted from device.sh to eliminate circular dependencies

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: device_config.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${IOS_DEVICE_CONFIG_LOADED:-}" = "1" ] && [ "${IOS_DEVICE_CONFIG_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_DEVICE_CONFIG_LOADED=1
IOS_DEVICE_CONFIG_LOADED_PID="$$"

# Source dependencies
if [ -n "${IOS_SCRIPTS_DIR:-}" ]; then
  if [ -f "${IOS_SCRIPTS_DIR}/lib.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/lib.sh"
  fi
  if [ -f "${IOS_SCRIPTS_DIR}/core.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/core.sh"
  fi
fi

# ============================================================================
# Device File Management Functions
# ============================================================================

# List all device JSON files in directory
# Args: devices_dir
# Returns: sorted list of device files
ios_device_files() {
  dir="$1"
  if [ -z "$dir" ]; then
    return 1
  fi
  find "$dir" -type f -name '*.json' | sort
}

# List device files selected by IOS_DEVICES config
# Args: devices_dir
# Returns: filtered list of device files
ios_selected_device_files() {
  devices_dir="$1"

  # Read IOS_DEVICES from environment (comma or space separated)
  selections="${IOS_DEVICES:-}"
  selections="$(echo "$selections" | tr ',' ' ')"

  if [ -z "$selections" ]; then
    # Empty = all devices
    ios_device_files "$devices_dir"
    return 0
  fi

  matched=""
  for file in $(ios_device_files "$devices_dir"); do
    base="$(basename "$file")"
    base="${base%.json}"
    name="$(jq -r '.name // empty' "$file")"
    for selection in $selections; do
      if [ "$selection" = "$base" ] || [ "$selection" = "$name" ]; then
        matched="${matched}${file}
"
        break
      fi
    done
  done
  if [ -z "$matched" ]; then
    echo "No iOS device definitions matched IOS_DEVICES='${IOS_DEVICES}'." >&2
    return 1
  fi
  printf '%s' "$matched"
}

# Get runtime for device by name
# Args: device_name
# Returns: runtime version
ios_device_runtime_for_name() {
  name="$1"
  dir="$(ios_devices_dir 2>/dev/null || true)"
  if [ -z "$dir" ]; then
    return 1
  fi
  for file in $(ios_device_files "$dir"); do
    file_name="$(jq -r '.name // empty' "$file")"
    if [ -n "$file_name" ] && [ "$file_name" = "$name" ]; then
      runtime="$(jq -r '.runtime // empty' "$file")"
      if [ -n "$runtime" ]; then
        printf '%s\n' "$runtime"
        return 0
      fi
    fi
  done
  return 1
}

# ============================================================================
# Device Selection Functions
# ============================================================================

# Select device name from directory by selection criteria
# Args: selection, devices_dir
# Returns: device name
ios_select_device_name() {
  selection="$1"
  dir="$2"
  if [ -z "$dir" ]; then
    return 1
  fi
  if [ -n "$selection" ]; then
    for file in $(ios_device_files "$dir"); do
      base="$(basename "$file")"
      base="${base%.json}"
      name="$(jq -r '.name // empty' "$file")"
      if [ "$selection" = "$base" ] || [ "$selection" = "$name" ]; then
        printf '%s\n' "$name"
        return 0
      fi
    done
    echo "Warning: iOS device '${selection}' not found in ${dir}; using first definition." >&2
  fi
  first_file="$(ios_device_files "$dir" | head -n1)"
  if [ -n "$first_file" ]; then
    first_name="$(jq -r '.name // empty' "$first_file")"
    if [ -n "$first_name" ]; then
      printf '%s\n' "$first_name"
      return 0
    fi
  fi
  return 1
}

ios_debug_log_script "device_config.sh"
