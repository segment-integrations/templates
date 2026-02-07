#!/usr/bin/env sh
set -eu

# devices.sh is a CLI script and can be executed directly
# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

usage() {
  cat >&2 <<'USAGE'
Usage: devices.sh <command> [args]
       DEVICES_CMD="list" devices.sh

Commands:
  list                                     List all device definitions
  show <name>                              Show specific device JSON
  create <name> --runtime <version>        Create new device definition
  update <name> [--name <new>] [--runtime <version>]  Update existing device
  delete <name>                            Remove device definition
  eval                                     Generate devices.lock from IOS_DEVICES
  sync                                     Ensure simulators match device definitions

Device Selection:
  Set IOS_DEVICES env var in devbox.json (comma-separated, empty = all):
    {"IOS_DEVICES": "min,max"}

Runtime values: run `xcrun simctl list runtimes` and use the iOS version (e.g. 17.5).
Device names: run `xcrun simctl list devicetypes` and use the exact name.

Examples:
  devices.sh list
  devices.sh create iphone15 --runtime 17.5
  devices.sh eval
  devices.sh sync
USAGE
  exit 1
}

if [ -z "${1-}" ] && [ -n "${DEVICES_CMD:-}" ]; then
  set -- $DEVICES_CMD
fi

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

# Use lib.sh functions for path resolution
devices_dir="$(ios_devices_dir 2>/dev/null || echo "./devbox.d/ios/devices")"

# Ensure jq is available
ios_require_jq

resolve_device_file() {
  selection="$1"
  if [ -z "$selection" ]; then
    return 1
  fi
  if [ -f "$devices_dir/${selection}.json" ]; then
    printf '%s\n' "$devices_dir/${selection}.json"
    return 0
  fi
  for file in "$devices_dir"/*.json; do
    [ -f "$file" ] || continue
    name="$(jq -r '.name // empty' "$file")"
    if [ "$name" = "$selection" ]; then
      printf '%s\n' "$file"
      return 0
    fi
  done
  return 1
}

validate_runtime() {
  value="$1"
  case "$value" in
    ''|*[!0-9.]*|.*.|*..*)
      echo "Invalid runtime: $value" >&2
      exit 1
      ;;
  esac
}

case "$command_name" in
  list)
    for file in "$devices_dir"/*.json; do
      [ -f "$file" ] || continue
      jq -r '"\(.name // "")\t\(.runtime // "")\t\(. | @json)"' "$file"
    done
    ;;
  show)
    name="${1-}"
    [ -n "$name" ] || usage
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    cat "$file"
    ;;
  create)
    name="${1-}"
    [ -n "$name" ] || usage
    shift || true
    runtime=""
    while [ "${1-}" != "" ]; do
      case "$1" in
        --runtime) runtime="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [ -n "$runtime" ] || { echo "--runtime is required" >&2; exit 1; }
    validate_runtime "$runtime"
    mkdir -p "$devices_dir"
    jq -n --arg name "$name" --arg runtime "$runtime" '{name:$name, runtime:$runtime}' >"$devices_dir/${name}.json"
    ;;
  update)
    name="${1-}"
    [ -n "$name" ] || usage
    shift || true
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    new_name=""
    runtime=""
    while [ "${1-}" != "" ]; do
      case "$1" in
        --name) new_name="$2"; shift 2 ;;
        --runtime) runtime="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    if [ -n "$runtime" ]; then
      validate_runtime "$runtime"
    fi
    tmp="${file}.tmp"
    jq \
      --arg name "$new_name" \
      --arg runtime "$runtime" \
      '(
        if $name != "" then .name=$name else . end
      ) | (
        if $runtime != "" then .runtime=$runtime else . end
      )' "$file" >"$tmp"
    mv "$tmp" "$file"
    if [ -n "$new_name" ]; then
      mv "$file" "$devices_dir/${new_name}.json"
    fi
    ;;
  delete)
    name="${1-}"
    [ -n "$name" ] || usage
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    rm -f "$file"
    ;;
  select)
    # Select specific devices and update lock file directly
    [ "${1-}" != "" ] || usage
    if [ ! -d "$devices_dir" ]; then
      echo "ERROR: Devices directory not found: $devices_dir" >&2
      exit 1
    fi

    # Build JSON array from selected device files
    devices_json="["
    first=true
    for selected_name in "$@"; do
      # Try filename match first
      device_file="${devices_dir}/${selected_name}.json"
      if [ ! -f "$device_file" ]; then
        # Try name field match
        device_file=""
        for file in "$devices_dir"/*.json; do
          [ -f "$file" ] || continue
          name="$(jq -r '.name // empty' "$file")"
          if [ "$name" = "$selected_name" ]; then
            device_file="$file"
            break
          fi
        done
      fi

      if [ -z "$device_file" ] || [ ! -f "$device_file" ]; then
        echo "ERROR: Device '$selected_name' not found in ${devices_dir}" >&2
        exit 1
      fi

      if [ "$first" = true ]; then
        first=false
      else
        devices_json="${devices_json},"
      fi
      devices_json="${devices_json}$(cat "$device_file")"
    done
    devices_json="${devices_json}]"

    # Compute checksum
    checksum="$(ios_compute_devices_checksum "$devices_dir" 2>/dev/null || echo "")"

    # Generate lock file
    lock_path="${devices_dir%/}/devices.lock"
    temp_lock="${lock_path}.tmp"

    echo "$devices_json" | jq \
      --arg cs "$checksum" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)" \
      '{devices: ., checksum: $cs, generated_at: $ts}' > "$temp_lock"
    mv "$temp_lock" "$lock_path"

    device_count="$(echo "$devices_json" | jq '. | length')"
    echo "Selected iOS devices: $*"
    echo "Lock file updated: ${device_count} devices"
    ;;
  reset)
    # Reset just calls eval to regenerate from all files
    echo "Regenerating lock file from all device files..."
    exec "$0" eval
    ;;
  eval)
    # Generate lock file from all device files
    if [ ! -d "$devices_dir" ]; then
      echo "ERROR: Devices directory not found: $devices_dir" >&2
      exit 1
    fi

    # Build JSON array of all device configs
    devices_json="$(
      for device_file in "$devices_dir"/*.json; do
        [ -f "$device_file" ] || continue
        cat "$device_file"
      done | jq -s '.'
    )"

    device_count="$(echo "$devices_json" | jq '. | length')"
    if [ "$device_count" -eq 0 ]; then
      echo "ERROR: No device definitions found in ${devices_dir}" >&2
      exit 1
    fi

    # Compute checksum using lib.sh function
    checksum="$(ios_compute_devices_checksum "$devices_dir" 2>/dev/null || echo "")"

    # Generate lock file
    lock_path="${devices_dir%/}/devices.lock"
    temp_lock="${lock_path}.tmp"

    echo "$devices_json" | jq \
      --arg cs "$checksum" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)" \
      '{devices: ., checksum: $cs, generated_at: $ts}' > "$temp_lock"
    mv "$temp_lock" "$lock_path"

    echo "Lock file generated: ${device_count} devices"
    ;;

  # --------------------------------------------------------------------------
  # Sync: Ensure simulators match device definitions
  # --------------------------------------------------------------------------
  sync)
    # Source device.sh for device management functions
    if [ ! -f "$script_dir/device.sh" ]; then
      echo "ERROR: device.sh not found in ${script_dir}" >&2
      exit 1
    fi
    . "$script_dir/device.sh"

    # Check if devices.lock exists
    lock_path="${devices_dir%/}/devices.lock"
    if [ ! -f "$lock_path" ]; then
      echo "ERROR: devices.lock not found at $lock_path" >&2
      echo "       Run 'devices.sh eval' first or ensure IOS_DEVICES is set" >&2
      exit 1
    fi

    # Validate lock file format
    if ! jq -e '.devices' "$lock_path" >/dev/null 2>&1; then
      echo "ERROR: Invalid devices.lock format" >&2
      exit 1
    fi

    # Get device count
    device_count="$(jq '.devices | length' "$lock_path")"
    if [ "$device_count" -eq 0 ]; then
      echo "No devices defined in lock file"
      exit 0
    fi

    echo "Syncing simulators with device definitions..."
    echo "================================================"

    # Counters for summary
    matched=0
    recreated=0
    created=0
    skipped=0

    # Create temp files for each device definition
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' EXIT

    # Extract each device from lock file and sync
    device_index=0
    while [ "$device_index" -lt "$device_count" ]; do
      device_json="$temp_dir/device_${device_index}.json"
      jq -c ".devices[$device_index]" "$lock_path" > "$device_json"

      # Call ensure function and track result
      if ios_ensure_device_from_definition "$device_json"; then
        result=$?
        case $result in
          0) matched=$((matched + 1)) ;;
          1) recreated=$((recreated + 1)) ;;
          2) created=$((created + 1)) ;;
        esac
      else
        skipped=$((skipped + 1))
      fi

      device_index=$((device_index + 1))
    done

    echo "================================================"
    echo "Sync complete:"
    echo "  ✓ Matched:   $matched"
    if [ "$recreated" -gt 0 ]; then
      echo "  🔄 Recreated: $recreated"
    fi
    if [ "$created" -gt 0 ]; then
      echo "  ➕ Created:   $created"
    fi
    if [ "$skipped" -gt 0 ]; then
      echo "  ⚠ Skipped:   $skipped"
    fi
    ;;

  *)
    usage
    ;;
esac
