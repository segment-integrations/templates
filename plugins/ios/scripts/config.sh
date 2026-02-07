#!/usr/bin/env sh
# iOS Plugin - Configuration Management
# See REFERENCE.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: config.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_CONFIG_LOADED:-}" = "1" ] && [ "${IOS_CONFIG_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_CONFIG_LOADED=1
IOS_CONFIG_LOADED_PID="$$"

# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

ios_debug_log "config.sh loaded"

# ============================================================================
# Config Management Functions
# ============================================================================

# Show current configuration
ios_config_show() {
  echo "Current iOS configuration (from environment variables):"
  echo ""
  echo "Device Selection:"
  echo "  IOS_DEVICES: ${IOS_DEVICES:-(all devices)}"
  echo ""
  echo "Default Device:"
  echo "  IOS_DEFAULT_DEVICE: ${IOS_DEFAULT_DEVICE:-max}"
  echo "  IOS_DEFAULT_RUNTIME: ${IOS_DEFAULT_RUNTIME:-(auto)}"
  echo ""
  echo "Application:"
  echo "  IOS_APP_PROJECT: ${IOS_APP_PROJECT:-*.xcodeproj}"
  echo "  IOS_APP_SCHEME: ${IOS_APP_SCHEME:-(auto)}"
  echo "  IOS_APP_BUNDLE_ID: ${IOS_APP_BUNDLE_ID:-com.example.ios}"
  echo "  IOS_APP_ARTIFACT: ${IOS_APP_ARTIFACT:-.devbox/virtenv/ios/DerivedData/...}"
  echo ""
  echo "Paths:"
  echo "  IOS_CONFIG_DIR: ${IOS_CONFIG_DIR:-.}"
  echo "  IOS_DEVICES_DIR: ${IOS_DEVICES_DIR:-./devbox.d/ios/devices}"
  echo "  IOS_DEVELOPER_DIR: ${IOS_DEVELOPER_DIR:-(auto)}"
  echo ""
  echo "To override values, set environment variables in your devbox.json:"
  echo '  "env": {'
  echo '    "IOS_DEVICES": "min,max",'
  echo '    "IOS_DEFAULT_DEVICE": "min",'
  echo '    "IOS_APP_PROJECT": "MyApp.xcodeproj"'
  echo '  }'
}

# Set configuration values
# Args: key=value pairs
ios_config_set() {
  echo "Configuration is now managed via environment variables." >&2
  echo "" >&2
  echo "To override configuration values, add them to your devbox.json:" >&2
  echo "" >&2
  echo '{' >&2
  echo '  "include": [' >&2
  echo '    "plugin:ios"' >&2
  echo '  ],' >&2
  echo '  "env": {' >&2

  # Show the key=value pairs they wanted to set as examples
  if [ -n "${1-}" ]; then
    echo "    # Add these overrides:" >&2
    while [ "${1-}" != "" ]; do
      pair="$1"
      key="${pair%%=*}"
      value="${pair#*=}"
      echo "    \"${key}\": \"${value}\"," >&2
      shift
    done
  fi

  echo '  }' >&2
  echo '}' >&2
  echo "" >&2
  echo "After updating devbox.json, run 'devbox shell' to apply changes." >&2
  return 1
}

# Reset configuration to defaults
ios_config_reset() {
  echo "Configuration is now managed via environment variables." >&2
  echo "" >&2
  echo "To reset to defaults, remove any IOS_* environment variable" >&2
  echo "overrides from your devbox.json env section." >&2
  echo "" >&2
  echo "Plugin defaults are defined in the ios plugin.json file." >&2
  echo "Run 'ios.sh config show' to see current values." >&2
  return 1
}
