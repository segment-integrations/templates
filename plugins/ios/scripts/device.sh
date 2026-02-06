#!/usr/bin/env sh
# iOS Plugin - Device and Runtime Management
# See REFERENCE.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: device.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_DEVICE_LOADED:-}" = "1" ] && [ "${IOS_DEVICE_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_DEVICE_LOADED=1
IOS_DEVICE_LOADED_PID="$$"

# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

ios_debug_log "device.sh loaded"

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

# List device files selected by EVALUATE_DEVICES config
# Args: devices_dir
# Returns: filtered list of device files
ios_selected_device_files() {
  devices_dir="$1"
  config_path="$(ios_config_path 2>/dev/null || true)"
  if [ -z "$config_path" ] || [ ! -f "$config_path" ]; then
    ios_device_files "$devices_dir"
    return 0
  fi
  selections="$(jq -r '.EVALUATE_DEVICES // [] | if length == 0 then empty else .[] end' "$config_path")"
  if [ -z "$selections" ]; then
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
    echo "No iOS device definitions matched EVALUATE_DEVICES in ${config_path}." >&2
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

# Helper function to resolve developer dir (sources env.sh)
ios_resolve_developer_dir() {
  if [ -n "${IOS_DEVELOPER_DIR:-}" ] && [ -d "${IOS_DEVELOPER_DIR}" ]; then
    printf '%s\n' "${IOS_DEVELOPER_DIR}"
    return 0
  fi

  # Try xcode-select
  if command -v xcode-select >/dev/null 2>&1; then
    desired="$(xcode-select -p 2>/dev/null || true)"
    if [ -n "$desired" ] && [ -d "$desired" ]; then
      printf '%s\n' "$desired"
      return 0
    fi
  fi

  # Fallback to default Xcode location
  if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    printf '%s\n' "/Applications/Xcode.app/Contents/Developer"
    return 0
  fi

  return 1
}
