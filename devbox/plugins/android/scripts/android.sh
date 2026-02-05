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
  config show                  Display android.json configuration
  config set KEY=VALUE [...]   Update configuration values
  config reset                 Reset to default configuration
  info                         Display resolved SDK information

Examples:
  android.sh devices list
  android.sh devices create pixel_api28 --api 28 --device pixel
  android.sh config set ANDROID_DEFAULT_DEVICE=max
  android.sh config show
  android.sh info
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
config_path="${config_dir%/}/android.json"
scripts_dir="${ANDROID_SCRIPTS_DIR:-${config_dir%/}/scripts}"

# ============================================================================
# Helper Functions
# ============================================================================

# Ensure lib.sh is loaded for shared utilities
ensure_lib_loaded() {
  if ! command -v android_require_jq >/dev/null 2>&1; then
    if [ -f "${scripts_dir}/lib.sh" ]; then
      . "${scripts_dir}/lib.sh"
    else
      echo "ERROR: lib.sh not found. Cannot continue." >&2
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
    devices_script="${scripts_dir%/}/devices.sh"
    if [ ! -x "$devices_script" ]; then
      echo "ERROR: devices.sh not found or not executable: $devices_script" >&2
      exit 1
    fi
    exec "$devices_script" "$@"
    ;;

  # --------------------------------------------------------------------------
  # config - Configuration management
  # --------------------------------------------------------------------------
  config)
    subcommand="${1-}"
    shift || true

    ensure_lib_loaded
    android_require_jq

    case "$subcommand" in
      # Show current configuration
      show)
        if [ ! -f "$config_path" ]; then
          echo "ERROR: Configuration file not found: $config_path" >&2
          exit 1
        fi
        cat "$config_path"
        ;;

      # Set configuration key=value pairs
      set)
        if [ -z "${1-}" ]; then
          echo "ERROR: No key=value pairs provided" >&2
          usage
        fi

        if [ ! -f "$config_path" ]; then
          echo "ERROR: Configuration file not found: $config_path" >&2
          exit 1
        fi

        # Build jq filter for all key=value updates
        temp_file="${config_path}.tmp"
        jq_filter='.'

        while [ "${1-}" != "" ]; do
          key_value_pair="$1"
          config_key="${key_value_pair%%=*}"
          config_value="${key_value_pair#*=}"

          # Validate key exists in config
          if [ -z "$config_key" ] || [ "$config_key" = "$config_value" ]; then
            echo "ERROR: Invalid key=value format: $key_value_pair" >&2
            echo "       Expected: KEY=VALUE" >&2
            exit 1
          fi

          if ! jq -e --arg key "$config_key" 'has($key)' "$config_path" >/dev/null 2>&1; then
            echo "ERROR: Unknown configuration key: $config_key" >&2
            echo "       Run 'android.sh config show' to see available keys" >&2
            exit 1
          fi

          # Add to jq filter
          jq_filter="$jq_filter | .${config_key} = \"${config_value}\""
          shift
        done

        # Apply all updates atomically
        jq "$jq_filter" "$config_path" > "$temp_file"
        mv "$temp_file" "$config_path"
        echo "Configuration updated successfully"
        ;;

      # Reset to default configuration
      reset)
        # Find default config template
        default_config=""
        if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
          default_config_candidate="${ANDROID_SCRIPTS_DIR%/}/../config/android.json"
          if [ -f "$default_config_candidate" ]; then
            default_config="$default_config_candidate"
          fi
        fi

        if [ -z "$default_config" ]; then
          echo "ERROR: Default configuration not found" >&2
          echo "       Reinstall the Android plugin to restore defaults" >&2
          exit 1
        fi

        cp "$default_config" "$config_path"
        echo "Configuration reset to defaults: $config_path"
        ;;

      *)
        echo "ERROR: Unknown config subcommand: $subcommand" >&2
        usage
        ;;
    esac
    ;;

  # --------------------------------------------------------------------------
  # info - Display SDK information
  # --------------------------------------------------------------------------
  info)
    # Source env.sh to get android_show_summary function
    env_script="${scripts_dir}/env.sh"
    if [ ! -f "$env_script" ]; then
      echo "ERROR: env.sh not found: $env_script" >&2
      exit 1
    fi

    # shellcheck source=/dev/null
    . "$env_script"

    # Call summary function (defined in env.sh)
    if command -v android_show_summary >/dev/null 2>&1; then
      android_show_summary
    else
      echo "ERROR: android_show_summary function not available" >&2
      exit 1
    fi
    ;;

  # --------------------------------------------------------------------------
  # Unknown command
  # --------------------------------------------------------------------------
  *)
    echo "ERROR: Unknown command: $command_name" >&2
    usage
    ;;
esac
