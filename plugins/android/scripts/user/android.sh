#!/usr/bin/env sh
# Android Plugin - Main CLI Entry Point
#
# This is the primary command-line interface for Android plugin operations.
# It routes commands to appropriate handlers.
#
# User-Overridable Variables:
#   ANDROID_CONFIG_DIR - Android configuration directory (default: devbox.d/android)
#   ANDROID_SCRIPTS_DIR - Scripts directory

set -eu

# ============================================================================
# Usage and Help
# ============================================================================

usage() {
  cat >&2 <<'USAGE'
Usage: android.sh <command> [args]

Commands:
  devices <command> [args]     Manage device definitions
  info                         Display resolved SDK information
  emulator start [device]      Start Android emulator
  emulator stop                Stop running emulator
  emulator reset               Reset all emulator AVDs
  deploy [device]              Deploy and launch app on emulator

Examples:
  android.sh devices list
  android.sh devices create pixel_api28 --api 28 --device pixel
  android.sh info
  android.sh emulator start max
  android.sh emulator stop
  android.sh deploy max

Note: Configuration is managed via environment variables in devbox.json.
USAGE
  exit 1
}

# ============================================================================
# Initialize Variables
# ============================================================================

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

# Local variables (derived from user-overridable variables)
config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
scripts_dir="${ANDROID_SCRIPTS_DIR:-${config_dir%/}/scripts}"

# ============================================================================
# Helper Functions
# ============================================================================

# Ensure lib.sh is loaded for shared utilities
ensure_lib_loaded() {
  if ! command -v android_require_jq >/dev/null 2>&1; then
    if [ -f "${scripts_dir}/lib/lib.sh" ]; then
      . "${scripts_dir}/lib/lib.sh"
    else
      echo "ERROR: lib/lib.sh not found. Cannot continue." >&2
      exit 1
    fi
  fi
}

# ============================================================================
# Command Handlers
# ============================================================================

case "$command_name" in
  # --------------------------------------------------------------------------
  # devices - Delegate to devices.sh
  # --------------------------------------------------------------------------
  devices)
    devices_script="${scripts_dir%/}/user/devices.sh"
    if [ ! -x "$devices_script" ]; then
      echo "ERROR: devices.sh not found or not executable: $devices_script" >&2
      exit 1
    fi
    exec "$devices_script" "$@"
    ;;

  # --------------------------------------------------------------------------
  # info - Display SDK information
  # --------------------------------------------------------------------------
  info)
    # Source core.sh to get android_show_summary function
    ensure_lib_loaded

    core_script="${scripts_dir}/platform/core.sh"
    if [ ! -f "$core_script" ]; then
      echo "ERROR: platform/core.sh not found: $core_script" >&2
      exit 1
    fi

    # shellcheck source=/dev/null
    . "$core_script"

    # Call summary function (defined in core.sh)
    if command -v android_show_summary >/dev/null 2>&1; then
      android_show_summary
    else
      echo "ERROR: android_show_summary function not available" >&2
      exit 1
    fi
    ;;

  # --------------------------------------------------------------------------
  # emulator - Emulator lifecycle management
  # --------------------------------------------------------------------------
  emulator)
    subcommand="${1-}"
    shift || true

    # Source layer 3 dependencies (emulator needs AVD functions)
    avd_script="${scripts_dir%/}/domain/avd.sh"
    emulator_script="${scripts_dir%/}/domain/emulator.sh"

    if [ ! -f "$avd_script" ]; then
      echo "ERROR: domain/avd.sh not found: $avd_script" >&2
      exit 1
    fi
    if [ ! -f "$emulator_script" ]; then
      echo "ERROR: domain/emulator.sh not found: $emulator_script" >&2
      exit 1
    fi

    # Source avd.sh first (emulator depends on it)
    # shellcheck source=/dev/null
    . "$avd_script"
    # shellcheck source=/dev/null
    . "$emulator_script"

    case "$subcommand" in
      start)
        device_name="${1:-}"

        # Layer 3 orchestration: setup AVDs first, then start emulator
        if ! command -v android_setup_avds >/dev/null 2>&1; then
          echo "ERROR: android_setup_avds function not available" >&2
          exit 1
        fi
        if ! command -v android_start_emulator >/dev/null 2>&1; then
          echo "ERROR: android_start_emulator function not available" >&2
          exit 1
        fi

        # Step 1: Setup AVDs (ensures they exist and match definitions)
        echo "Setting up Android Virtual Devices..."
        android_setup_avds

        # Step 2: Start emulator (uses ANDROID_RESOLVED_AVD from setup)
        android_start_emulator "$device_name"
        ;;

      stop)
        if command -v android_stop_emulator >/dev/null 2>&1; then
          android_stop_emulator
        else
          echo "ERROR: android_stop_emulator function not available" >&2
          exit 1
        fi
        ;;

      reset)
        avd_reset_script="${scripts_dir%/}/domain/avd-reset.sh"
        if [ ! -f "$avd_reset_script" ]; then
          echo "ERROR: domain/avd-reset.sh not found: $avd_reset_script" >&2
          exit 1
        fi
        # shellcheck source=/dev/null
        . "$avd_reset_script"

        if command -v android_stop_emulator >/dev/null 2>&1 && command -v android_reset_avds >/dev/null 2>&1; then
          android_stop_emulator
          android_reset_avds
        else
          echo "ERROR: Required functions not available" >&2
          exit 1
        fi
        ;;

      *)
        echo "ERROR: Unknown emulator subcommand: $subcommand" >&2
        echo "Usage: android.sh emulator <start|stop|reset> [device]" >&2
        exit 1
        ;;
    esac
    ;;

  # --------------------------------------------------------------------------
  # deploy - Deploy and launch app on emulator
  # --------------------------------------------------------------------------
  deploy)
    device_name="${1:-}"

    # Source layer 3 dependencies
    avd_script="${scripts_dir%/}/domain/avd.sh"
    emulator_script="${scripts_dir%/}/domain/emulator.sh"
    deploy_script="${scripts_dir%/}/domain/deploy.sh"

    for script in "$avd_script" "$emulator_script" "$deploy_script"; do
      if [ ! -f "$script" ]; then
        echo "ERROR: Required script not found: $script" >&2
        exit 1
      fi
    done

    # Source all layer 3 scripts (order doesn't matter - they're independent)
    # shellcheck source=/dev/null
    . "$avd_script"
    # shellcheck source=/dev/null
    . "$emulator_script"
    # shellcheck source=/dev/null
    . "$deploy_script"

    # Verify functions are available
    for func in android_setup_avds android_start_emulator android_deploy_app; do
      if ! command -v "$func" >/dev/null 2>&1; then
        echo "ERROR: $func function not available" >&2
        exit 1
      fi
    done

    # Layer 4 orchestration: setup → start → deploy
    echo "Setting up Android Virtual Devices..."
    android_setup_avds

    echo ""
    echo "Starting emulator..."
    android_start_emulator "$device_name"

    echo ""
    android_deploy_app "$device_name"
    ;;

  # --------------------------------------------------------------------------
  # Unknown command
  # --------------------------------------------------------------------------
  *)
    echo "ERROR: Unknown command: $command_name" >&2
    usage
    ;;
esac
