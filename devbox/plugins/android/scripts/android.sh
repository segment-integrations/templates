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
  config show                  Display current configuration (generated from env vars)
  config set KEY=VALUE [...]   Show how to override config via devbox.json env vars
  config reset                 Show how to reset to defaults
  info                         Display resolved SDK information

Examples:
  android.sh devices list
  android.sh devices create pixel_api28 --api 28 --device pixel
  android.sh config show
  android.sh info

Note: Configuration is managed via environment variables in devbox.json.
      Use 'config set' to see examples of how to override values.
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
# Generated config in virtenv (created by android-init.sh from env vars)
generated_config="${scripts_dir%/}/../android.json"

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
        echo "Current Android configuration (generated from environment variables):"
        echo ""
        if [ -f "$generated_config" ]; then
          cat "$generated_config"
        else
          echo "ERROR: Generated configuration not found: $generated_config" >&2
          echo "       Run 'devbox shell' to initialize the environment" >&2
          exit 1
        fi
        echo ""
        echo "To override values, set environment variables in your devbox.json:"
        echo '  "env": {'
        echo '    "ANDROID_COMPILE_SDK": "35",'
        echo '    "ANDROID_TARGET_SDK": "35"'
        echo '  }'
        ;;

      # Set configuration key=value pairs
      set)
        echo "Configuration is now managed via environment variables." >&2
        echo "" >&2
        echo "To override configuration values, add them to your devbox.json:" >&2
        echo "" >&2
        echo '{' >&2
        echo '  "include": [' >&2
        echo '    "plugin:android"' >&2
        echo '  ],' >&2
        echo '  "env": {' >&2

        # Show the key=value pairs they wanted to set as examples
        if [ -n "${1-}" ]; then
          echo "    # Add these overrides:" >&2
          while [ "${1-}" != "" ]; do
            key_value_pair="$1"
            config_key="${key_value_pair%%=*}"
            config_value="${key_value_pair#*=}"
            echo "    \"${config_key}\": \"${config_value}\"," >&2
            shift
          done
        fi

        echo '  }' >&2
        echo '}' >&2
        echo "" >&2
        echo "After updating devbox.json, run 'devbox shell' to apply changes." >&2
        exit 1
        ;;

      # Reset to default configuration
      reset)
        echo "Configuration is now managed via environment variables." >&2
        echo "" >&2
        echo "To reset to defaults, remove any ANDROID_* environment variable" >&2
        echo "overrides from your devbox.json env section." >&2
        echo "" >&2
        echo "Plugin defaults are defined in the android plugin.json file." >&2
        echo "Run 'android.sh config show' to see current values." >&2
        exit 1
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
