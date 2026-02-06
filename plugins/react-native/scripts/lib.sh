#!/usr/bin/env sh
# React Native Plugin - Core Utilities
# See REFERENCE.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: lib.sh must be sourced" >&2
  exit 1
fi

if [ "${REACT_NATIVE_LIB_LOADED:-}" = "1" ] && [ "${REACT_NATIVE_LIB_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
REACT_NATIVE_LIB_LOADED=1
REACT_NATIVE_LIB_LOADED_PID="$$"

# Debug logging helper
react_native_debug_log() {
  if [ "${REACT_NATIVE_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]; then
    printf 'DEBUG: %s\n' "$*"
  fi
}

# Path resolution with fallback priority:
# REACT_NATIVE_CONFIG_DIR > DEVBOX_PROJECT_ROOT > DEVBOX_PROJECT_DIR > DEVBOX_WD > ./
react_native_config_path() {
  if [ -n "${REACT_NATIVE_CONFIG_DIR:-}" ] && [ -f "${REACT_NATIVE_CONFIG_DIR%/}/react-native.json" ]; then
    printf '%s\n' "${REACT_NATIVE_CONFIG_DIR%/}/react-native.json"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -f "${DEVBOX_PROJECT_ROOT}/devbox.d/react-native.json" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT}/devbox.d/react-native.json"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -f "${DEVBOX_PROJECT_DIR}/devbox.d/react-native.json" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR}/devbox.d/react-native.json"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ] && [ -f "${DEVBOX_WD}/devbox.d/react-native.json" ]; then
    printf '%s\n' "${DEVBOX_WD}/devbox.d/react-native.json"
    return 0
  fi
  if [ -f "./devbox.d/react-native.json" ]; then
    printf '%s\n' "./devbox.d/react-native.json"
    return 0
  fi
  return 1
}

# Requirement checks
react_native_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required" >&2
    exit 1
  fi
}

react_native_require_tool() {
  tool_name="$1"
  error_message="${2:-Missing required tool: $tool_name}"
  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "ERROR: $error_message" >&2
    exit 1
  fi
}

react_native_debug_log "lib.sh loaded"
