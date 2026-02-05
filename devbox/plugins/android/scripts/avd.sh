#!/usr/bin/env sh
# Android Plugin - AVD Management
# See SCRIPTS.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: avd.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_AVD_LOADED:-}" = "1" ] && [ "${ANDROID_AVD_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_AVD_LOADED=1
ANDROID_AVD_LOADED_PID="$$"

# ============================================================================
# Device Hardware Profile Resolution
# ============================================================================

# Resolve device hardware profile with fuzzy matching
android_resolve_device_hardware() {
  desired_device="$1"

  if [ -z "$desired_device" ]; then
    return 1
  fi

  # Get list of available devices from avdmanager
  available_devices="$(avdmanager list device | awk -F': ' '
    /^id: /{
      id=$2
      # Handle quoted IDs
      if (index(id, "\"") > 0) {
        q=index(id, "\"")
        rest=substr(id, q + 1)
        q2=index(rest, "\"")
        if (q2 > 0) { id=substr(rest, 1, q2 - 1) }
      } else {
        # Handle space-separated IDs
        split(id, parts, " ")
        id=parts[1]
      }
      next
    }
    /^[[:space:]]*Name: /{
      name=$2
      if (id != "") { print id "\t" name; id="" }
    }
  ')"

  if [ -z "$available_devices" ]; then
    return 1
  fi

  # Normalize desired device name for fuzzy matching
  desired_normalized="$(android_normalize_name "$desired_device")"
  desired_alt_normalized="$(android_normalize_name "$(printf '%s' "$desired_device" | tr '_-' '  ')")"

  # Try to find matching device
  # shellcheck disable=SC3003
  while IFS=$'\t' read -r device_id device_name; do
    id_normalized="$(android_normalize_name "$device_id")"
    name_normalized="$(android_normalize_name "$device_name")"

    # Match on ID or name, trying both normalized forms
    if [ "$id_normalized" = "$desired_normalized" ] || \
       [ "$id_normalized" = "$desired_alt_normalized" ] || \
       [ "$name_normalized" = "$desired_normalized" ] || \
       [ "$name_normalized" = "$desired_alt_normalized" ]; then
      printf '%s\n' "$device_id"
      return 0
    fi
  done <<EOF
$available_devices
EOF

  return 1
}

# ============================================================================
# ABI Selection
# ============================================================================

# Get ABI candidates based on preference and host architecture
android_get_abi_candidates() {
  preferred_abi="${1:-}"
  host_arch="${2:-$(uname -m)}"

  # If user specified a preference, only try that one
  if [ -n "$preferred_abi" ]; then
    printf '%s' "$preferred_abi"
    return 0
  fi

  # Otherwise, select based on host architecture
  # arm64/aarch64 hosts: Prefer arm64-v8a, then x86_64, then x86
  # Other hosts: Prefer x86_64, then x86, then arm64-v8a
  case "$host_arch" in
    arm64|aarch64)
      printf '%s' "arm64-v8a x86_64 x86"
      ;;
    *)
      printf '%s' "x86_64 x86 arm64-v8a"
      ;;
  esac
}

# ============================================================================
# System Image Resolution
# ============================================================================

# Find system image matching API level, tag, and ABI preference
android_pick_system_image() {
  api_level="$1"
  system_image_tag="$2"
  preferred_abi="${3:-}"

  # Get ABI candidates in priority order
  abi_candidates="$(android_get_abi_candidates "$preferred_abi")"

  # Try each ABI until we find an installed image
  for abi in $abi_candidates; do
    image_path="${ANDROID_SDK_ROOT}/system-images/android-${api_level}/${system_image_tag}/${abi}"
    image_package="system-images;android-${api_level};${system_image_tag};${abi}"

    if android_debug_enabled; then
      android_debug_log "Checking system image: $image_path"
    fi

    if [ -d "$image_path" ]; then
      printf '%s\n' "$image_package"
      return 0
    fi
  done

  return 1
}

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

# ============================================================================
# Java Resolution
# ============================================================================

# Resolve Java home directory (ANDROID_JAVA_HOME > JAVA_HOME > PATH)
android_resolve_java_home() {
  # Priority 1: ANDROID_JAVA_HOME
  if [ -n "${ANDROID_JAVA_HOME:-}" ] && [ -x "$ANDROID_JAVA_HOME/bin/java" ]; then
    printf '%s\n' "$ANDROID_JAVA_HOME"
    return 0
  fi

  # Priority 2: JAVA_HOME
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    printf '%s\n' "$JAVA_HOME"
    return 0
  fi

  # Priority 3: java in PATH
  java_bin="$(command -v java 2>/dev/null || true)"
  if [ -n "$java_bin" ]; then
    # Derive JAVA_HOME from binary location
    java_home="$(cd "$(dirname "$java_bin")/.." && pwd)"
    if [ -x "$java_home/bin/java" ]; then
      printf '%s\n' "$java_home"
      return 0
    fi
  fi

  return 1
}

# ============================================================================
# AVD Manager Operations
# ============================================================================

# Run avdmanager with correct Java environment
android_run_avdmanager() {
  if [ -n "${ANDROID_JAVA_HOME:-}" ]; then
    JAVA_HOME="$ANDROID_JAVA_HOME" \
    PATH="$ANDROID_JAVA_HOME/bin:$PATH" \
      avdmanager "$@"
  else
    avdmanager "$@"
  fi
}

# Check if an AVD exists
android_avd_exists() {
  avd_name="$1"

  android_run_avdmanager list avd | grep -q "Name: ${avd_name}"
}

# Create an Android Virtual Device (AVD)
android_create_avd() {
  avd_name="$1"
  device_hardware="$2"
  system_image_package="$3"

  # Extract ABI from package name (last component after ;)
  image_abi="${system_image_package##*;}"

  # Check if AVD already exists
  if android_avd_exists "$avd_name"; then
    echo "AVD already exists: ${avd_name}"
    return 0
  fi

  # Create the AVD
  echo "Creating AVD: ${avd_name} with ${system_image_package}..."

  android_run_avdmanager create avd \
    --force \
    --name "$avd_name" \
    --package "$system_image_package" \
    --device "$device_hardware" \
    --abi "$image_abi" \
    --sdcard 512M
}

# ============================================================================
# AVD Setup
# ============================================================================

# Setup AVDs from device definition files
android_setup_avds() {
  # ---- Validate Environment ----

  # Ensure SDK is available
  if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -z "${ANDROID_HOME:-}" ]; then
    echo "ERROR: ANDROID_SDK_ROOT/ANDROID_HOME must be set" >&2
    echo "       Ensure the Devbox Android SDK package is installed" >&2
    exit 1
  fi

  # Set ANDROID_HOME for compatibility
  ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
  export ANDROID_HOME

  # Require necessary tools
  android_require_tool avdmanager
  android_require_tool emulator
  android_require_tool jq

  # Resolve and export Java home
  java_home="$(android_resolve_java_home 2>/dev/null || true)"
  if [ -n "$java_home" ]; then
    ANDROID_JAVA_HOME="$java_home"
    export ANDROID_JAVA_HOME
  fi

  # ---- Find Device Definitions ----

  devices_dir="$(android_get_devices_dir 2>/dev/null || true)"
  if [ -z "$devices_dir" ]; then
    echo "ERROR: Android devices directory not found" >&2
    echo "       Expected devbox.d/android/devices or ANDROID_DEVICES_DIR" >&2
    exit 1
  fi

  device_files="$(android_select_device_files "$devices_dir")"
  if [ -z "$device_files" ]; then
    echo "ERROR: No Android device definitions found in ${devices_dir}" >&2
    exit 1
  fi

  # ---- Process Each Device ----

  # Track first AVD name for convenience
  first_avd_name=""

  # Get default system image tag
  default_image_tag="${ANDROID_SYSTEM_IMAGE_TAG:-google_apis}"

  for device_file in $device_files; do
    echo ""
    echo "Processing device definition: $(basename "$device_file")"

    # Parse device definition
    device_name="$(jq -r '.name // empty' "$device_file")"
    api_level="$(jq -r '.api // empty' "$device_file")"
    device_hardware="$(jq -r '.device // empty' "$device_file")"
    image_tag="$(jq -r '.tag // empty' "$device_file")"
    preferred_abi="$(jq -r '.preferred_abi // empty' "$device_file")"

    # Validate required fields
    if [ -z "$api_level" ] || [ -z "$device_hardware" ]; then
      echo "ERROR: Device definition missing required fields (api, device) in ${device_file}" >&2
      exit 1
    fi

    # Use default tag if not specified
    if [ -z "$image_tag" ]; then
      image_tag="$default_image_tag"
    fi

    echo "  Device: $device_hardware"
    echo "  API: $api_level"
    echo "  Tag: $image_tag"
    [ -n "$preferred_abi" ] && echo "  Preferred ABI: $preferred_abi"

    # Resolve device hardware profile
    resolved_hardware="$(android_resolve_device_hardware "$device_hardware" 2>/dev/null || true)"
    if [ -n "$resolved_hardware" ]; then
      device_hardware="$resolved_hardware"
      echo "  Resolved hardware: $device_hardware"
    fi

    # Find compatible system image
    system_image="$(android_pick_system_image "$api_level" "$image_tag" "$preferred_abi" 2>/dev/null || true)"
    if [ -z "$system_image" ]; then
      echo "ERROR: No compatible system image found for API ${api_level} (${image_tag})" >&2
      echo "       Preferred ABI: ${preferred_abi:-auto}" >&2
      echo "       Check: ${ANDROID_SDK_ROOT}/system-images/android-${api_level}" >&2
      echo "       Re-enter devbox shell to download system images" >&2
      continue
    fi

    # Generate AVD name
    if [ -n "$device_name" ]; then
      avd_name="$device_name"
    else
      # Auto-generate name from device and API
      image_abi="${system_image##*;}"
      safe_abi="$(printf '%s' "$image_abi" | tr '-' '_')"
      safe_device="$(android_sanitize_avd_name "$device_hardware" || echo "device")"
      avd_name="${safe_device}_API${api_level}_${safe_abi}"
    fi

    echo "  AVD name: $avd_name"

    # Create the AVD
    android_create_avd "$avd_name" "$device_hardware" "$system_image"

    # Track first AVD
    if [ -z "$first_avd_name" ]; then
      first_avd_name="$avd_name"
    fi

    # Confirm AVD is ready
    if android_avd_exists "$avd_name"; then
      echo "  ✓ AVD ready: ${avd_name}"
    fi
  done

  # Export first AVD name for convenience
  if [ -n "$first_avd_name" ]; then
    ANDROID_RESOLVED_AVD="$first_avd_name"
    export ANDROID_RESOLVED_AVD
    echo ""
    echo "Default AVD: $first_avd_name"
  fi

  echo ""
  echo "AVD setup complete!"
  echo "Start emulator: emulator -avd <name> --netdelay none --netspeed full"
}

# ============================================================================
# AVD Reset
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

# Delete specific AVD(s) by name
android_delete_avd() {
  avd_name="$1"

  if [ -z "$avd_name" ]; then
    return 1
  fi

  if ! android_avd_exists "$avd_name"; then
    echo "AVD not found: $avd_name"
    return 0
  fi

  echo "Deleting AVD: $avd_name"
  android_run_avdmanager delete avd --name "$avd_name"
  echo "  ✓ AVD deleted: $avd_name"
}

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

# ============================================================================
# Source Additional Modules
# ============================================================================

# Get script directory for sourcing other modules
script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -d "${ANDROID_SCRIPTS_DIR}" ]; then
  script_dir="${ANDROID_SCRIPTS_DIR}"
fi

# Source emulator and deployment modules
if [ -f "$script_dir/emulator.sh" ]; then
  . "$script_dir/emulator.sh"
fi

if [ -f "$script_dir/deploy.sh" ]; then
  . "$script_dir/deploy.sh"
fi

# Convenience aliases for common operations
android_service() {
  android_run_emulator_service "$@"
}

android_run_app() {
  android_deploy_app "$@"
}

android_debug_log_script "avd.sh"
