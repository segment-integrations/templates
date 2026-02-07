#!/usr/bin/env sh
# iOS Plugin - Device and Simulator Management
# Extracted from device.sh to eliminate circular dependencies

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: device_manager.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${IOS_DEVICE_MANAGER_LOADED:-}" = "1" ] && [ "${IOS_DEVICE_MANAGER_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_DEVICE_MANAGER_LOADED=1
IOS_DEVICE_MANAGER_LOADED_PID="$$"

# Source dependencies
if [ -n "${IOS_SCRIPTS_DIR:-}" ]; then
  if [ -f "${IOS_SCRIPTS_DIR}/lib.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/lib.sh"
  fi
  if [ -f "${IOS_SCRIPTS_DIR}/core.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/core.sh"
  fi
  if [ -f "${IOS_SCRIPTS_DIR}/device_config.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/device_config.sh"
  fi
fi

# ============================================================================
# Runtime Management Functions
# ============================================================================

# Pick runtime from available iOS runtimes
# Args: preferred_version
# Returns: runtime_id|runtime_name
pick_runtime() {
  preferred="$1"
  json="$(xcrun simctl list runtimes -j)"
  choice="$(echo "$json" | jq -r --arg v "$preferred" '.runtimes[] | select(.isAvailable and (.name|startswith("iOS \($v)"))) | "\(.identifier)|\(.name)"' | head -n1)"
  if [ -z "$choice" ] || [ "$choice" = "null" ]; then
    choice="$(echo "$json" | jq -r '.runtimes[] | select(.isAvailable and (.name|startswith("iOS "))) | "\(.version)|\(.identifier)|\(.name)"' | sort -Vr | head -n1 | cut -d"|" -f2-)"
  fi
  if [ -n "$choice" ] && [ "$choice" != "null" ]; then
    printf '%s\n' "$choice"
    return 0
  fi
  return 1
}

# Resolve runtime with auto-download fallback
# Args: preferred_version
# Returns: runtime_id|runtime_name
resolve_runtime() {
  preferred="$1"
  if choice="$(pick_runtime "$preferred")"; then
    printf '%s\n' "$choice"
    return 0
  fi

  if [ "${IOS_DOWNLOAD_RUNTIME:-1}" != "0" ] && command -v xcodebuild >/dev/null 2>&1; then
    echo "Preferred runtime iOS ${preferred} not found. Attempting to download via xcodebuild -downloadPlatform iOS..." >&2
    if xcodebuild -downloadPlatform iOS; then
      if choice="$(pick_runtime "$preferred")"; then
        printf '%s\n' "$choice"
        return 0
      fi
    else
      echo "xcodebuild -downloadPlatform iOS failed; continuing with available runtimes." >&2
    fi
  fi

  pick_runtime "$preferred"
}

# Resolve runtime strictly (no fallback to latest)
# Args: preferred_version
# Returns: runtime_id|runtime_name
resolve_runtime_strict() {
  preferred="$1"
  if choice="$(pick_runtime "$preferred")"; then
    printf '%s\n' "$choice"
    return 0
  fi

  if [ "${IOS_DOWNLOAD_RUNTIME:-1}" != "0" ] && command -v xcodebuild >/dev/null 2>&1; then
    echo "Preferred runtime iOS ${preferred} not found. Attempting to download via xcodebuild -downloadPlatform iOS..." >&2
    if xcodebuild -downloadPlatform iOS; then
      if choice="$(pick_runtime "$preferred")"; then
        printf '%s\n' "$choice"
        return 0
      fi
    else
      echo "xcodebuild -downloadPlatform iOS failed." >&2
    fi
  fi

  echo "Preferred runtime iOS ${preferred} not found." >&2
  return 1
}

# Resolve runtime name only
# Args: preferred_version
# Returns: runtime_name
resolve_runtime_name() {
  preferred="$1"
  choice="$(resolve_runtime "$preferred" || true)"
  if [ -n "$choice" ]; then
    printf '%s\n' "$choice" | cut -d'|' -f2
    return 0
  fi
  return 1
}

# Resolve runtime name strictly
# Args: preferred_version
# Returns: runtime_name
resolve_runtime_name_strict() {
  preferred="$1"
  choice="$(resolve_runtime_strict "$preferred" || true)"
  if [ -n "$choice" ]; then
    printf '%s\n' "$choice" | cut -d'|' -f2
    return 0
  fi
  return 1
}

# ============================================================================
# Simulator Device Queries
# ============================================================================

# Get UDID for existing device with any runtime
# Args: device_name
# Returns: UDID
existing_device_udid_any_runtime() {
  name="$1"
  xcrun simctl list devices -j | jq -r --arg name "$name" '.devices[]?[]? | select(.name == $name) | .udid' | head -n1
}

# Check if device data directory exists
# Args: udid
# Returns: 0 if exists, 1 otherwise
device_data_dir_exists() {
  udid="${1:-}"
  if [ -z "$udid" ]; then
    return 1
  fi
  dir="$HOME/Library/Developer/CoreSimulator/Devices/$udid"
  [ -d "$dir" ]
}

# Get device type identifier for device name
# Args: device_name
# Returns: device_type_id
devicetype_id_for_name() {
  name="$1"
  xcrun simctl list devicetypes -j | jq -r --arg name "$name" '.devicetypes[] | select((.name|ascii_downcase) == ($name|ascii_downcase)) | .identifier' | head -n1
}

# ============================================================================
# Device Creation and Management
# ============================================================================

# Ensure device exists, creating it if necessary
# Args: base_name, preferred_runtime
# Returns: 0 on success
ensure_device() {
  base_name="$1"
  preferred_runtime="$2"

  existing_udid="$(existing_device_udid_any_runtime "$base_name")"
  if [ -n "$existing_udid" ]; then
    if device_data_dir_exists "$existing_udid"; then
      echo "Found existing ${base_name}: ${existing_udid}"
      return 0
    fi
    echo "Existing ${base_name} (${existing_udid}) is missing its data directory. Deleting stale simulator..."
    xcrun simctl delete "$existing_udid" || true
  fi

  choice="$(resolve_runtime "$preferred_runtime" || true)"
  if [ -z "$choice" ]; then
    echo "No available iOS simulator runtime found. Install one in Xcode (Settings > Platforms) and retry." >&2
    return 1
  fi
  runtime_id="$(printf '%s' "$choice" | cut -d'|' -f1)"
  runtime_name="$(printf '%s' "$choice" | cut -d'|' -f2)"

  display_name="${base_name} (${runtime_name})"

  device_type="$(devicetype_id_for_name "$base_name" || true)"
  if [ -z "$device_type" ]; then
    echo "Device type '${base_name}' is unavailable in this Xcode install. Skipping ${display_name}." >&2
    return 0
  fi

  existing_udid="$(existing_device_udid_any_runtime "$display_name")"
  if [ -n "$existing_udid" ]; then
    if device_data_dir_exists "$existing_udid"; then
      echo "Found existing ${display_name}: ${existing_udid}"
      return 0
    fi
    echo "Existing ${display_name} (${existing_udid}) is missing its data directory. Deleting stale simulator..."
    xcrun simctl delete "$existing_udid" || true
  fi

  echo "Creating ${display_name}..."
  xcrun simctl create "$display_name" "$device_type" "$runtime_id"
  echo "Created ${display_name}"
}

# ============================================================================
# Device Sync Functions
# ============================================================================

# Get runtime version from device name
# Args: device_name
# Returns: runtime version (e.g., "17.5")
ios_get_device_runtime() {
  name="$1"
  xcrun simctl list devices -j | jq -r --arg name "$name" '
    .devices[] as $devices |
    ($devices | keys[0]) as $runtime_key |
    $devices[$runtime_key][] |
    select(.name == $name) |
    ($runtime_key | capture("iOS-(?<version>[0-9]+\\.[0-9]+)") | .version)
  ' | head -n1
}

# Ensure device from definition file matches or is created
# Args: device_file
# Returns: 0 if matched, 1 if recreated, 2 if created new
ios_ensure_device_from_definition() {
  file="$1"

  name="$(jq -r '.name // empty' "$file")"
  runtime="$(jq -r '.runtime // empty' "$file")"

  if [ -z "$name" ] || [ -z "$runtime" ]; then
    echo "  ⚠ Invalid device definition in $file"
    return 0
  fi

  # Resolve runtime strictly (don't fallback)
  choice="$(resolve_runtime_strict "$runtime" || true)"
  if [ -z "$choice" ]; then
    echo "  ⚠ Runtime iOS $runtime not available, skipping $name"
    return 0
  fi

  runtime_id="$(printf '%s' "$choice" | cut -d'|' -f1)"
  runtime_name="$(printf '%s' "$choice" | cut -d'|' -f2)"

  # Get device type
  device_type="$(devicetype_id_for_name "$name" || true)"
  if [ -z "$device_type" ]; then
    echo "  ⚠ Device type '$name' not available, skipping"
    return 0
  fi

  # Build full device name with runtime
  full_name="${name} (${runtime_name})"

  # Check if device exists
  existing_udid="$(existing_device_udid_any_runtime "$full_name" || true)"

  if [ -z "$existing_udid" ]; then
    # Device doesn't exist - create it
    echo "  ➕ Creating device: $full_name"
    xcrun simctl create "$full_name" "$device_type" "$runtime_id" >/dev/null 2>&1
    return 2
  fi

  # Device exists - check if it has the correct runtime
  current_runtime="$(ios_get_device_runtime "$full_name" || true)"

  if [ "$current_runtime" = "$runtime" ]; then
    echo "  ✓ Matched: $full_name"
    return 0
  fi

  # Runtime mismatch - recreate device
  echo "  🔄 Recreating device: $full_name (iOS $current_runtime → $runtime)"
  xcrun simctl delete "$existing_udid" >/dev/null 2>&1 || true
  xcrun simctl create "$full_name" "$device_type" "$runtime_id" >/dev/null 2>&1
  return 1
}

# ============================================================================
# System Setup Functions
# ============================================================================

# Ensure DEVELOPER_DIR is set correctly
# Returns: 0 on success
ensure_developer_dir() {
  desired="${IOS_DEVELOPER_DIR:-}"
  PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
  export PATH
  if [ -z "$desired" ]; then
    desired="$(ios_resolve_developer_dir 2>/dev/null || true)"
  fi

  ios_require_dir "$desired" "Xcode developer directory not found. Install Xcode/CLI tools or set IOS_DEVELOPER_DIR to an Xcode path (e.g., /Applications/Xcode.app/Contents/Developer)."
  ios_require_dir_contains "$desired" "Toolchains/XcodeDefault.xctoolchain" "Xcode toolchain missing under ${desired}."
  ios_require_dir_contains "$desired" "Platforms/iPhoneSimulator.platform" "iPhoneSimulator platform missing under ${desired}."

  DEVELOPER_DIR="$desired"
  PATH="$DEVELOPER_DIR/usr/bin:$PATH"
  export DEVELOPER_DIR PATH
  return 0
}

# Check if simctl is available
# Returns: 0 on success, exits on failure
ensure_simctl() {
  if xcrun -f simctl >/dev/null 2>&1; then
    return 0
  fi
  cat >&2 <<'EOM'
Missing simctl.
- The standalone Command Line Tools do NOT include simctl; you need full Xcode.
- Install/locate Xcode.app, then select it:
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
- You can also set IOS_DEVELOPER_DIR to your Xcode path for this script.
EOM
  exit 1
}

ios_debug_log_script "device_manager.sh"
