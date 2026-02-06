#!/usr/bin/env sh
# iOS Plugin - Simulator Lifecycle Management
# See REFERENCE.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: simulator.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_SIMULATOR_LOADED:-}" = "1" ] && [ "${IOS_SIMULATOR_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_SIMULATOR_LOADED=1
IOS_SIMULATOR_LOADED_PID="$$"

# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"
# shellcheck disable=SC1090
. "$script_dir/device.sh"

ios_debug_log "simulator.sh loaded"

# ============================================================================
# Simulator Health Functions
# ============================================================================

# Check CoreSimulatorService health
# Returns: 0 if healthy, 1 otherwise
ensure_core_sim_service() {
  status=0
  output="$(xcrun simctl list devices -j 2>&1)" || status=$?
  if [ "$status" -ne 0 ]; then
    echo "simctl failed while listing devices (status ${status}). CoreSimulatorService may be unhealthy." >&2
    echo "Try restarting it:" >&2
    echo "  killall -9 com.apple.CoreSimulatorService 2>/dev/null || true" >&2
    # shellcheck disable=SC3028
    echo "  launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService" >&2
    echo "Then open Simulator once and rerun devbox run setup-ios." >&2
    echo "simctl error output:" >&2
    echo "$output" >&2
    return 1
  fi

  if echo "$output" | grep -q "CoreSimulatorService connection became invalid"; then
    echo "CoreSimulatorService is not healthy. Try restarting it:" >&2
    echo "  killall -9 com.apple.CoreSimulatorService 2>/dev/null || true" >&2
    # shellcheck disable=SC3028
    echo "  launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService" >&2
    echo "Then open Simulator once and rerun devbox run setup-ios." >&2
    echo "simctl error output:" >&2
    echo "$output" >&2
    return 1
  fi
}

# ============================================================================
# Device Name Resolution
# ============================================================================

# Resolve device name for simulator operations
# Returns: device name from IOS_SIM_DEVICE, IOS_DEVICE_NAME, or default device
resolve_service_device_name() {
  if [ -n "${IOS_SIM_DEVICE:-}" ]; then
    printf '%s\n' "$IOS_SIM_DEVICE"
    return 0
  fi
  if [ -n "${IOS_DEVICE_NAME:-}" ]; then
    printf '%s\n' "$IOS_DEVICE_NAME"
    return 0
  fi
  devices_dir="$(ios_devices_dir 2>/dev/null || true)"
  if [ -n "$devices_dir" ]; then
    selection="${IOS_DEFAULT_DEVICE:-}"
    ios_select_device_name "$selection" "$devices_dir" && return 0
  fi
  return 1
}

# ============================================================================
# Simulator Start/Stop Functions
# ============================================================================

# Start iOS simulator
# Args: device_name (optional)
# Returns: 0 on success
ios_start() {
  if [ -n "${1:-}" ]; then
    IOS_DEVICE_NAME="$1"
    export IOS_DEVICE_NAME
  fi
  headless="${SIM_HEADLESS:-}"

  ensure_developer_dir
  ios_require_tool jq
  ensure_simctl
  if ! ensure_core_sim_service; then
    return 1
  fi

  device_base="$(resolve_service_device_name || true)"
  if [ -z "$device_base" ]; then
    echo "No iOS simulator device configured; set IOS_DEVICE_NAME or IOS_DEFAULT_DEVICE." >&2
    return 1
  fi

  preferred_runtime="$(ios_device_runtime_for_name "$device_base" || true)"
  if [ -z "$preferred_runtime" ]; then
    preferred_runtime="${IOS_DEFAULT_RUNTIME:-}"
    if [ -z "$preferred_runtime" ] && command -v xcrun >/dev/null 2>&1; then
      preferred_runtime="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
    fi
  fi
  choice="$(resolve_runtime "$preferred_runtime" || true)"
  if [ -z "$choice" ]; then
    echo "No available iOS simulator runtime found. Install one in Xcode (Settings > Platforms) and retry." >&2
    return 1
  fi
  runtime_name="$(printf '%s' "$choice" | cut -d'|' -f2)"

  ensure_device "$device_base" "$preferred_runtime"
  display_name="${device_base} (${runtime_name})"
  udid="$(xcrun simctl list devices -j | jq -r --arg name "$display_name" '.devices[]?[]? | select(.name == $name) | .udid' | head -n1)"
  if [ -z "$udid" ]; then
    udid="$(existing_device_udid_any_runtime "$device_base" || true)"
  fi
  if [ -z "$udid" ]; then
    echo "Unable to resolve iOS simulator device for ${display_name}." >&2
    return 1
  fi

  IOS_SIM_UDID="$udid"
  IOS_SIM_NAME="$display_name"
  export IOS_SIM_UDID IOS_SIM_NAME

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  if ! xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1; then
    while true; do
      state="$(xcrun simctl list devices -j | jq -r --arg udid "$udid" '.devices[]?[]? | select(.udid == $udid) | .state' | head -n1)"
      [ "$state" = "Booted" ] && break
      sleep 5
    done
  fi

  if [ -z "$headless" ]; then
    open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
  fi
  echo "iOS simulator booted: ${display_name} (${udid}, headless=${headless:-0})"
}

# Stop iOS simulator
# Returns: 0 on success
ios_stop() {
  udid="${IOS_SIM_UDID:-}"
  if [ -z "$udid" ] && [ -n "${IOS_SIM_NAME:-}" ]; then
    udid="$(xcrun simctl list devices -j | jq -r --arg name "$IOS_SIM_NAME" '.devices[]?[]? | select(.name == $name) | .udid' | head -n1)"
  fi
  if [ -n "$udid" ]; then
    echo "Stopping iOS simulator: ${udid}"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  else
    echo "Stopping booted iOS simulators (if any)."
    xcrun simctl shutdown booted >/dev/null 2>&1 || true
  fi
}

# Run simulator as a service (keeps running until stopped)
# Args: device_name (optional)
# Returns: 0 on success
ios_service() {
  ios_start "${1-}"

  trap 'ios_stop; exit 0' INT TERM

  udid="${IOS_SIM_UDID:-}"
  if [ -z "$udid" ]; then
    while true; do
      sleep 5
    done
  fi

  while true; do
    state="$(xcrun simctl list devices -j | jq -r --arg udid "$udid" '.devices[]?[]? | select(.udid == $udid) | .state' | head -n1)"
    [ -z "$state" ] && break
    [ "$state" = "Shutdown" ] && break
    sleep 5
  done
}
