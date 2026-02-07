#!/usr/bin/env sh
# iOS Plugin - Shell Initialization
# Sets up environment when user runs 'devbox shell'
# This is NOT meant to make all functions available - use ios.sh for that

if ! (return 0 2>/dev/null); then
  echo "templates/devbox/plugins/ios/scripts/env.sh must be sourced." >&2
  exit 1
fi

if [ "${IOS_ENV_LOADED:-}" = "1" ] && [ "${IOS_ENV_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_ENV_LOADED=1
IOS_ENV_LOADED_PID="$$"

# Determine scripts directory
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# ============================================================================
# Source only what we need for environment setup
# ============================================================================

# shellcheck disable=SC1090
. "$script_dir/lib.sh"      # Utility functions
# shellcheck disable=SC1090
. "$script_dir/core.sh"     # Platform setup (ios_setup_environment)

# ============================================================================
# Environment Setup
# ============================================================================

# Setup iOS environment
ios_setup_environment

# Detect Node.js binary (needed for React Native)
if [ -z "${IOS_NODE_BINARY:-}" ] && command -v node >/dev/null 2>&1; then
  IOS_NODE_BINARY="$(command -v node)"
  export IOS_NODE_BINARY
fi

# ============================================================================
# Validation
# ============================================================================

# Run non-blocking validation
if [ -f "${script_dir}/validate.sh" ]; then
  # shellcheck disable=SC1090
  . "${script_dir}/validate.sh"
  ios_validate_xcode || true
fi

# ============================================================================
# Summary Display
# ============================================================================

# Optionally print summary on init if INIT_IOS is set
if [ -n "${INIT_IOS:-}" ] && [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${IOS_SDK_SUMMARY_PRINTED:-}" ]; then
  IOS_SDK_SUMMARY_PRINTED=1
  export IOS_SDK_SUMMARY_PRINTED
  ios_show_summary
fi

# Optional debug output
if ios_debug_enabled; then
  ios_debug_log_script "templates/devbox/plugins/ios/scripts/env.sh"
  ios_debug_dump_vars \
    IOS_DEVICES \
    IOS_DEFAULT_DEVICE \
    IOS_DEFAULT_RUNTIME \
    IOS_DEVELOPER_DIR \
    IOS_DOWNLOAD_RUNTIME \
    DEVELOPER_DIR \
    SDKROOT \
    CC \
    CXX
fi
