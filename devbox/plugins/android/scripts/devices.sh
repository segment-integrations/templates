#!/usr/bin/env sh
# Android Plugin - Device Management CLI
#
# This script manages Android device definitions stored in devbox.d/android/devices/
#
# User-Overridable Variables:
#   ANDROID_CONFIG_DIR - Android configuration directory (default: devbox.d/android)
#   ANDROID_DEVICES_DIR - Device definitions directory (default: $ANDROID_CONFIG_DIR/devices)
#   ANDROID_SCRIPTS_DIR - Scripts directory
#   DEVICES_CMD - Command to execute (alternative to $1)

set -eu

# ============================================================================
# Usage and Help
# ============================================================================

usage() {
  cat >&2 <<'USAGE'
Usage: devices.sh <command> [args]
       DEVICES_CMD="list" devices.sh

Commands:
  list                                              List all device definitions
  show <name>                                       Show specific device JSON
  create <name> --api <n> --device <id> [options]  Create new device definition
  update <name> [options]                           Update existing device
  delete <name>                                     Remove device definition
  select <name...>                                  Select specific devices for evaluation
  reset                                             Reset device selection (all devices)
  eval                                              Generate devices.lock

Device Creation Options:
  --api <n>         Android API level (required, e.g., 28, 34)
  --device <id>     Device hardware profile (required, e.g., pixel, Nexus 5X)
  --tag <tag>       System image tag (optional)
  --abi <abi>       Preferred ABI (optional)

Tag values: default google_apis google_apis_playstore play_store aosp_atd google_atd
ABI values: arm64-v8a x86_64 x86

Examples:
  devices.sh list
  devices.sh create pixel_api28 --api 28 --device pixel --tag google_apis
  devices.sh select min max
  devices.sh reset
  devices.sh eval
USAGE
  exit 1
}

# ============================================================================
# Initialize Variables
# ============================================================================

# Allow command to be passed via DEVICES_CMD environment variable
if [ -z "${1-}" ] && [ -n "${DEVICES_CMD:-}" ]; then
  # shellcheck disable=SC2086
  set -- $DEVICES_CMD
fi

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

# Local variables (derived from user-overridable variables)
config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
devices_dir="${ANDROID_DEVICES_DIR:-${config_dir%/}/devices}"
scripts_dir="${ANDROID_SCRIPTS_DIR:-${config_dir%/}/scripts}"
lock_file_path="${devices_dir%/}/devices.lock"

# Constants: Allowed values for validation
readonly ALLOWED_TAGS="default google_apis google_apis_playstore play_store aosp_atd google_atd"
readonly ALLOWED_ABIS="arm64-v8a x86_64 x86"

# ============================================================================
# Helper Functions
# ============================================================================

# Ensure lib.sh is loaded for shared utilities
ensure_lib_loaded() {
  # Check if lib.sh functions are available
  if ! command -v android_require_jq >/dev/null 2>&1; then
    # Try to source lib.sh
    if [ -f "${scripts_dir}/lib.sh" ]; then
      . "${scripts_dir}/lib.sh"
    else
      echo "ERROR: lib.sh not found. Cannot continue." >&2
      exit 1
    fi
  fi
}

# Resolve device file path from device name or filename
#
# Tries two strategies:
#   1. Match by filename: devices_dir/<name>.json
#   2. Match by .name field in JSON files
#
# Parameters:
#   $1 - selection: Device name to find
#
# Returns:
#   Prints full path to device JSON file
#
# Exit codes:
#   0 - Device found
#   1 - Device not found
resolve_device_file() {
  selection="$1"

  if [ -z "$selection" ]; then
    return 1
  fi

  # Strategy 1: Try direct filename match
  candidate_file="$devices_dir/${selection}.json"
  if [ -f "$candidate_file" ]; then
    printf '%s\n' "$candidate_file"
    return 0
  fi

  # Strategy 2: Search for .name field match in all device files
  for device_file in "$devices_dir"/*.json; do
    [ -f "$device_file" ] || continue

    device_name="$(jq -r '.name // empty' "$device_file")"
    if [ "$device_name" = "$selection" ]; then
      printf '%s\n' "$device_file"
      return 0
    fi
  done

  return 1
}

# Validate API level is numeric
#
# Parameters:
#   $1 - api_value: API level to validate
validate_api() {
  api_value="$1"

  case "$api_value" in
    ''|*[!0-9]*)
      echo "ERROR: Invalid api: $api_value (must be numeric, e.g., 28, 34)" >&2
      exit 1
      ;;
  esac
}

# Validate system image tag is in allowed list
#
# Parameters:
#   $1 - tag_value: Tag to validate
validate_tag() {
  tag_value="$1"

  for allowed_tag in $ALLOWED_TAGS; do
    if [ "$allowed_tag" = "$tag_value" ]; then
      return 0
    fi
  done

  echo "ERROR: Invalid tag: $tag_value" >&2
  echo "       Allowed: $ALLOWED_TAGS" >&2
  exit 1
}

# Validate ABI is in allowed list
#
# Parameters:
#   $1 - abi_value: ABI to validate
validate_abi() {
  abi_value="$1"

  for allowed_abi in $ALLOWED_ABIS; do
    if [ "$allowed_abi" = "$abi_value" ]; then
      return 0
    fi
  done

  echo "ERROR: Invalid abi: $abi_value" >&2
  echo "       Allowed: $ALLOWED_ABIS" >&2
  exit 1
}

# ============================================================================
# Initialize
# ============================================================================

# Load shared utilities (but don't require jq yet)
ensure_lib_loaded

# Setup jq wrapper - use system jq if available, otherwise use nix-shell
if command -v jq >/dev/null 2>&1; then
  # System jq available - use it directly
  jq() { command jq "$@"; }
elif command -v nix >/dev/null 2>&1; then
  # No system jq, but nix is available - use ephemeral shell
  jq() {
    # shellcheck disable=SC3050
    nix-shell -p jq --run "jq $(printf '%q ' "$@")" 2>/dev/null
  }
else
  # Neither jq nor nix available
  echo "ERROR: jq is required but not found" >&2
  echo "       Install jq or ensure nix is available" >&2
  exit 1
fi

# ============================================================================
# Command Handlers
# ============================================================================

case "$command_name" in
  # --------------------------------------------------------------------------
  # list - Display all device definitions
  # --------------------------------------------------------------------------
  list)
    for device_file in "$devices_dir"/*.json; do
      [ -f "$device_file" ] || continue
      jq -r '"\(.name // "")\t\(.api // "")\t\(.device // "")\t\(.tag // "")\t\(.preferred_abi // "")\t\(. | @json)"' "$device_file"
    done
    ;;

  # --------------------------------------------------------------------------
  # show - Display specific device definition
  # --------------------------------------------------------------------------
  show)
    device_name="${1-}"
    [ -n "$device_name" ] || usage

    device_file="$(resolve_device_file "$device_name")" || {
      echo "ERROR: Device not found: $device_name" >&2
      exit 1
    }

    cat "$device_file"
    ;;

  # --------------------------------------------------------------------------
  # create - Create new device definition
  # --------------------------------------------------------------------------
  create)
    device_name="${1-}"
    [ -n "$device_name" ] || usage
    shift || true

    # Parse options
    api_level=""
    device_hardware=""
    image_tag=""
    preferred_abi=""

    while [ "${1-}" != "" ]; do
      case "$1" in
        --api)
          api_level="$2"
          shift 2
          ;;
        --device)
          device_hardware="$2"
          shift 2
          ;;
        --tag)
          image_tag="$2"
          shift 2
          ;;
        --abi)
          preferred_abi="$2"
          shift 2
          ;;
        *)
          usage
          ;;
      esac
    done

    # Validate required fields
    [ -n "$api_level" ] || {
      echo "ERROR: --api is required" >&2
      exit 1
    }
    [ -n "$device_hardware" ] || {
      echo "ERROR: --device is required" >&2
      exit 1
    }

    # Validate field values
    validate_api "$api_level"
    if [ -n "$image_tag" ]; then
      validate_tag "$image_tag"
    fi
    if [ -n "$preferred_abi" ]; then
      validate_abi "$preferred_abi"
    fi

    # Create devices directory if it doesn't exist
    mkdir -p "$devices_dir"

    # Build JSON object with conditional fields
    device_json="$(jq -n \
      --arg name "$device_name" \
      --argjson api "$api_level" \
      --arg device "$device_hardware" \
      --arg tag "$image_tag" \
      --arg abi "$preferred_abi" \
      '{name:$name, api:$api, device:$device}
      + (if $tag != "" then {tag:$tag} else {} end)
      + (if $abi != "" then {preferred_abi:$abi} else {} end)'
    )"

    output_file="$devices_dir/${device_name}.json"
    printf '%s\n' "$device_json" > "$output_file"
    echo "Created device definition: $output_file"
    ;;

  # --------------------------------------------------------------------------
  # update - Update existing device definition
  # --------------------------------------------------------------------------
  update)
    device_name="${1-}"
    [ -n "$device_name" ] || usage
    shift || true

    device_file="$(resolve_device_file "$device_name")" || {
      echo "ERROR: Device not found: $device_name" >&2
      exit 1
    }

    # Parse options
    new_name=""
    api_level=""
    device_hardware=""
    image_tag=""
    preferred_abi=""

    while [ "${1-}" != "" ]; do
      case "$1" in
        --name)
          new_name="$2"
          shift 2
          ;;
        --api)
          api_level="$2"
          shift 2
          ;;
        --device)
          device_hardware="$2"
          shift 2
          ;;
        --tag)
          image_tag="$2"
          shift 2
          ;;
        --abi)
          preferred_abi="$2"
          shift 2
          ;;
        *)
          usage
          ;;
      esac
    done

    # Validate provided values
    if [ -n "$api_level" ]; then
      validate_api "$api_level"
    fi
    if [ -n "$image_tag" ]; then
      validate_tag "$image_tag"
    fi
    if [ -n "$preferred_abi" ]; then
      validate_abi "$preferred_abi"
    fi

    # Update JSON using jq
    temp_file="${device_file}.tmp"
    jq \
      --arg name "$new_name" \
      --arg api "$api_level" \
      --arg device "$device_hardware" \
      --arg tag "$image_tag" \
      --arg abi "$preferred_abi" \
      '(if $name != "" then .name=$name else . end)
      | (if $api != "" then .api=($api|tonumber) else . end)
      | (if $device != "" then .device=$device else . end)
      | (if $tag != "" then .tag=$tag else . end)
      | (if $abi != "" then .preferred_abi=$abi else . end)' \
      "$device_file" > "$temp_file"

    mv "$temp_file" "$device_file"

    # If name changed, rename the file
    if [ -n "$new_name" ]; then
      new_file="$devices_dir/${new_name}.json"
      mv "$device_file" "$new_file"
      echo "Updated and renamed device definition: $new_file"
    else
      echo "Updated device definition: $device_file"
    fi
    ;;

  # --------------------------------------------------------------------------
  # delete - Remove device definition
  # --------------------------------------------------------------------------
  delete)
    device_name="${1-}"
    [ -n "$device_name" ] || usage

    device_file="$(resolve_device_file "$device_name")" || {
      echo "ERROR: Device not found: $device_name" >&2
      exit 1
    }

    rm -f "$device_file"
    echo "Deleted device definition: $device_file"
    ;;

  # --------------------------------------------------------------------------
  # select - Select specific devices for evaluation (updates lock file directly)
  # --------------------------------------------------------------------------
  select)
    [ "${1-}" != "" ] || {
      echo "ERROR: No device names provided" >&2
      usage
    }

    # Get all device files as JSON
    devices_json="$(
      for device_file in $(find "$devices_dir" -name "*.json" -type f | sort); do
        jq -c --arg file "$device_file" \
          '. + {file: $file}' \
          "$device_file"
      done | jq -s '.'
    )"

    # Extract APIs from selected devices
    api_versions=""
    for selected_name in "$@"; do
      # Find matching device file
      matching_file="$(printf '%s\n' "$devices_json" | jq -r \
        --arg sel "$selected_name" \
        '.[] | select((.file | sub("^.*/"; "") | sub("\\.json$"; "")) == $sel or .name == $sel) | .file' \
        | head -n1)"

      if [ -z "$matching_file" ]; then
        echo "ERROR: Device '$selected_name' not found in ${devices_dir}" >&2
        exit 1
      fi

      # Extract API version
      api_version="$(printf '%s\n' "$devices_json" | jq -r \
        --arg file "$matching_file" \
        '.[] | select(.file == $file) | .api' \
        | head -n1)"

      if [ -n "$api_version" ] && [ "$api_version" != "null" ]; then
        api_versions="${api_versions}${api_versions:+
}${api_version}"
      fi
    done

    if [ -z "$api_versions" ]; then
      echo "ERROR: No API versions found for selected devices" >&2
      exit 1
    fi

    # Build devices array for lock file
    devices_array="["
    first=true
    for selected_name in "$@"; do
      matching_file="$(printf '%s\n' "$devices_json" | jq -r \
        --arg sel "$selected_name" \
        '.[] | select((.file | sub("^.*/"; "") | sub("\\.json$"; "")) == $sel or .name == $sel) | .file' \
        | head -n1)"

      if [ -n "$matching_file" ]; then
        device_config="$(cat "$matching_file")"
        if [ "$first" = true ]; then
          first=false
        else
          devices_array="${devices_array},"
        fi
        devices_array="${devices_array}${device_config}"
      fi
    done
    devices_array="${devices_array}]"

    # Compute checksum
    checksum="$(android_compute_devices_checksum "$devices_dir" || echo "")"

    # Generate lock file with full device configs (use existing lock_file_path from header)
    temp_lock_file="${lock_file_path}.tmp"
    echo "$devices_array" | jq \
      --arg cs "$checksum" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)" \
      '{devices: ., checksum: $cs, generated_at: $ts}' \
      > "$temp_lock_file"

    mv "$temp_lock_file" "$lock_file_path"

    # Update Android flake lock
    flake_dir="${config_dir}"
    if [ -f "${flake_dir}/flake.nix" ] && [ -f "${flake_dir}/flake.lock" ]; then
      if command -v nix >/dev/null 2>&1; then
        (cd "${flake_dir}" && nix flake update 2>&1 | grep -v "^warning:" || true) >/dev/null
      fi
    fi

    device_count="$(jq '.devices | length' "$lock_file_path")"
    selected_apis="$(jq -r '.devices | map(.api) | join(",")' "$lock_file_path")"
    echo "Selected Android devices: $*"
    echo "Lock file updated: ${device_count} devices with APIs ${selected_apis}"
    ;;

  # --------------------------------------------------------------------------
  # reset - Reset device selection to all devices (regenerate from all files)
  # --------------------------------------------------------------------------
  reset)
    echo "Regenerating lock file from all device files..."
    exec "$0" eval
    ;;

  # --------------------------------------------------------------------------
  # eval - Generate devices.lock from device definitions
  # --------------------------------------------------------------------------
  eval)
    if [ ! -d "$devices_dir" ]; then
      echo "ERROR: Devices directory not found: $devices_dir" >&2
      exit 1
    fi

    # Check if any device files exist
    device_files="$(ls "$devices_dir"/*.json 2>/dev/null || true)"
    if [ -z "$device_files" ]; then
      echo "ERROR: No device definitions found in ${devices_dir}" >&2
      exit 1
    fi

    # Build JSON array of device information (include all fields + file path)
    devices_json="$(
      for device_file in $device_files; do
        jq -c --arg path "$device_file" \
          '. + {file: $path}' \
          "$device_file"
      done | jq -s '.'
    )"

    # Eval scans ALL device files (no filtering) and generates full lock file
    # Use 'select' command to choose specific devices

    # Check we have at least one device
    device_count="$(printf '%s\n' "$devices_json" | jq '. | length')"
    if [ "$device_count" -eq 0 ]; then
      echo "ERROR: No device definitions found in ${devices_dir}" >&2
      exit 1
    fi

    # Compute checksum using shared utility function
    checksum="$(android_compute_devices_checksum "$devices_dir" || echo "")"

    # Check if checksum changed (to determine if we need to update flake)
    old_checksum=""
    if [ -f "$lock_file_path" ]; then
      old_checksum="$(jq -r '.checksum // ""' "$lock_file_path" 2>/dev/null || echo "")"
    fi
    checksum_changed=false
    if [ "$old_checksum" != "$checksum" ]; then
      checksum_changed=true
    fi

    # Generate lock file with full device configs (strip the .file field we added)
    temp_lock_file="${lock_file_path}.tmp"
    printf '%s\n' "$devices_json" | jq \
      --arg cs "$checksum" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)" \
      'map(del(.file)) | {devices: ., checksum: $cs, generated_at: $ts}' \
      > "$temp_lock_file"

    mv "$temp_lock_file" "$lock_file_path"

    # Update Android flake lock automatically if devices changed
    if [ "$checksum_changed" = true ]; then
      flake_dir="${config_dir}"
      if [ -f "${flake_dir}/flake.nix" ] && [ -f "${flake_dir}/flake.lock" ]; then
        if command -v nix >/dev/null 2>&1; then
          (cd "${flake_dir}" && nix flake update 2>&1 | grep -v "^warning:" || true) >/dev/null
        fi
      fi
    fi

    # Print summary
    device_count="$(jq '.devices | length' "$lock_file_path")"
    api_list="$(jq -r '.devices | map(.api) | join(",")' "$lock_file_path")"
    echo "Lock file generated: ${device_count} devices with APIs ${api_list}"
    ;;

  # --------------------------------------------------------------------------
  # Unknown command
  # --------------------------------------------------------------------------
  *)
    echo "ERROR: Unknown command: $command_name" >&2
    usage
    ;;
esac
