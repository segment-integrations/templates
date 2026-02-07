#!/usr/bin/env sh
# Android Plugin - Shell Initialization
# Sets up environment when user runs 'devbox shell'
# This is NOT meant to make all functions available - use android.sh for that

if ! (return 0 2>/dev/null); then
  echo "devbox.d/android/scripts/env.sh must be sourced." >&2
  exit 1
fi

if [ "${ANDROID_ENV_LOADED:-}" = "1" ] && [ "${ANDROID_ENV_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_ENV_LOADED=1
ANDROID_ENV_LOADED_PID="$$"

# ============================================================================
# Source only what we need for environment setup
# ============================================================================

if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  if [ -f "${ANDROID_SCRIPTS_DIR}/lib.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/lib.sh"      # Utility functions
  fi

  if [ -f "${ANDROID_SCRIPTS_DIR}/core.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/core.sh"     # Platform setup
  fi
fi

# ============================================================================
# Environment Setup
# ============================================================================

# Setup SDK environment and PATH
android_setup_sdk_environment
android_setup_path

# ============================================================================
# Validation
# ============================================================================

# Run validation (non-blocking)
if [ -f "${ANDROID_SCRIPTS_DIR}/validate.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/validate.sh"
  android_validate_sdk || true
fi

# ============================================================================
# Summary Display
# ============================================================================

# Optionally print summary on init if INIT_ANDROID is set
if [ -n "${INIT_ANDROID:-}" ] && [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${ANDROID_SDK_SUMMARY_PRINTED:-}" ]; then
  ANDROID_SDK_SUMMARY_PRINTED=1
  export ANDROID_SDK_SUMMARY_PRINTED
  android_show_summary
fi
