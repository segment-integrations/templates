#!/usr/bin/env sh
# Android Plugin - Core SDK and Environment Setup
# Extracted from env.sh to eliminate circular dependencies

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: core.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_CORE_LOADED:-}" = "1" ] && [ "${ANDROID_CORE_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_CORE_LOADED=1
ANDROID_CORE_LOADED_PID="$$"

# Source dependencies
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/lib.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib.sh"
fi

# ============================================================================
# Debug Utilities
# ============================================================================

android_debug_enabled() {
  [ "${ANDROID_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]
}

android_debug_log() {
  if android_debug_enabled; then
    printf '%s\n' "DEBUG: $*" >&2
  fi
}

android_debug_log_script() {
  if android_debug_enabled; then
    if (return 0 2>/dev/null); then
      context="sourced"
    else
      context="run"
    fi
    android_debug_log "$1 ($context)"
  fi
}

android_debug_dump_vars() {
  if android_debug_enabled; then
    for var in "$@"; do
      value="$(eval "printf '%s' \"\${$var-}\"")"
      printf 'DEBUG: %s=%s\n' "$var" "$value"
    done
  fi
}

# ============================================================================
# SDK Resolution
# ============================================================================

resolve_flake_sdk_root() {
  output="$1"
  if ! command -v nix >/dev/null 2>&1; then
    return 1
  fi
  root="${ANDROID_SDK_FLAKE_PATH:-}"
  if [ -z "$root" ]; then
    if [ -n "${ANDROID_FLAKE_DIR:-}" ] && [ -d "${ANDROID_FLAKE_DIR}" ]; then
      root="${ANDROID_FLAKE_DIR}"
    elif [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -d "${ANDROID_SCRIPTS_DIR}" ]; then
      # Flake is in same directory as scripts (virtenv)
      root="$(dirname "${ANDROID_SCRIPTS_DIR}")"
    elif [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -d "${DEVBOX_PROJECT_ROOT}/.devbox/virtenv/android" ]; then
      root="${DEVBOX_PROJECT_ROOT}/.devbox/virtenv/android"
    elif [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -d "${DEVBOX_PROJECT_DIR}/.devbox/virtenv/android" ]; then
      root="${DEVBOX_PROJECT_DIR}/.devbox/virtenv/android"
    elif [ -n "${DEVBOX_WD:-}" ] && [ -d "${DEVBOX_WD}/.devbox/virtenv/android" ]; then
      root="${DEVBOX_WD}/.devbox/virtenv/android"
    else
      root="./.devbox/virtenv/android"
    fi
    ANDROID_SDK_FLAKE_PATH="$root"
    export ANDROID_SDK_FLAKE_PATH
  fi
  if android_debug_enabled; then
    android_debug_log "Android SDK flake path: ${ANDROID_SDK_FLAKE_PATH:-$root}"
  fi

  # Show progress message if not in CI (only once per session)
  if [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${ANDROID_NIX_EVAL_SHOWN:-}" ]; then
    echo "🔍 Evaluating Android SDK from Nix flake..." >&2
    echo "   This may take a few minutes on first run" >&2
    export ANDROID_NIX_EVAL_SHOWN=1
  fi

  # Nix handles caching internally - no need for our own cache file
  sdk_out=$(
    nix --extra-experimental-features 'nix-command flakes' \
      eval --raw "path:${root}#${output}.outPath" 2>&1 || true
  )

  if android_debug_enabled; then
    android_debug_log "Flake eval returned: ${sdk_out:-empty}"
    if [ -n "$sdk_out" ]; then
      android_debug_log "Checking path: $sdk_out/libexec/android-sdk"
      if [ -d "$sdk_out/libexec/android-sdk" ]; then
        android_debug_log "Path exists!"
      else
        android_debug_log "Path does NOT exist. Checking alternatives..."
        android_debug_log "Direct path: $(ls -d "$sdk_out" 2>&1 | head -1)"
      fi
    fi
  fi

  if [ -n "${sdk_out:-}" ] && [ -d "$sdk_out/libexec/android-sdk" ]; then
    printf '%s\n' "$sdk_out/libexec/android-sdk"
    return 0
  fi
  return 1
}

detect_sdk_root_from_sdkmanager() {
  sm="$(command -v sdkmanager 2>/dev/null || true)"
  if [ -z "$sm" ]; then
    return 1
  fi
  if command -v readlink >/dev/null 2>&1; then
    sm="$(readlink "$sm" 2>/dev/null || printf '%s' "$sm")"
  fi
  sm_dir="$(cd "$(dirname "$sm")" && pwd)"
  candidates="${sm_dir}/.. ${sm_dir}/../share/android-sdk ${sm_dir}/../libexec/android-sdk ${sm_dir}/../.."
  for c in $candidates; do
    if [ -d "$c/platform-tools" ] || [ -d "$c/platforms" ] || [ -d "$c/system-images" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

detect_sdk_root_from_tools() {
  for tool in adb emulator; do
    bin_path="$(command -v "$tool" 2>/dev/null || true)"
    if [ -z "$bin_path" ]; then
      continue
    fi
    if command -v readlink >/dev/null 2>&1; then
      bin_path="$(readlink "$bin_path" 2>/dev/null || printf '%s' "$bin_path")"
    fi
    bin_dir="$(cd "$(dirname "$bin_path")" && pwd)"
    candidates="${bin_dir}/.. ${bin_dir}/../.."
    for c in $candidates; do
      if [ -d "$c/platform-tools" ] || [ -d "$c/emulator" ] || [ -d "$c/system-images" ]; then
        printf '%s\n' "$c"
        return 0
      fi
    done
  done
  return 1
}

# ============================================================================
# Environment Setup
# ============================================================================

android_setup_sdk_environment() {
  prefer_local="${ANDROID_LOCAL_SDK:-}"
  case "$prefer_local" in
    1 | true | TRUE | yes | YES | on | ON)
      prefer_local=1
      ;;
    *)
      prefer_local=""
      ;;
  esac

  if [ -z "${ANDROID_SDK_FLAKE_OUTPUT:-}" ]; then
    ANDROID_SDK_FLAKE_OUTPUT="android-sdk"
    export ANDROID_SDK_FLAKE_OUTPUT
  fi

  if [ -n "$prefer_local" ]; then
    if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -n "${ANDROID_HOME:-}" ]; then
      ANDROID_SDK_ROOT="$ANDROID_HOME"
    fi
    if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
      detected_root="$(detect_sdk_root_from_sdkmanager 2>/dev/null || true)"
      if [ -n "$detected_root" ]; then
        ANDROID_SDK_ROOT="$detected_root"
      fi
    fi
  else
    resolved_root="$(resolve_flake_sdk_root "$ANDROID_SDK_FLAKE_OUTPUT" || true)"
    if [ -n "$resolved_root" ]; then
      ANDROID_SDK_ROOT="$resolved_root"
      if [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -n "${ANDROID_NIX_EVAL_SHOWN:-}" ]; then
        echo "✓ Android SDK resolved from Nix flake" >&2
      fi
    fi
  fi

  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    detected_root="$(detect_sdk_root_from_sdkmanager 2>/dev/null || true)"
    if [ -n "$detected_root" ]; then
      ANDROID_SDK_ROOT="$detected_root"
    fi
  fi

  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    detected_root="$(detect_sdk_root_from_tools 2>/dev/null || true)"
    if [ -n "$detected_root" ]; then
      ANDROID_SDK_ROOT="$detected_root"
    fi
  fi

  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    # Warn but don't fail - SDK will be checked when actually needed (e.g., emulator start)
    # Don't warn during device eval or CI
    if [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${ANDROID_DEVICES_EVAL:-}" ]; then
      # Only warn if Nix is NOT available and no local SDK is configured
      # (If Nix is available, the cache just needs time to warm up on first run)
      if ! command -v nix >/dev/null 2>&1 && [ "${ANDROID_LOCAL_SDK:-0}" = "0" ]; then
        echo "WARNING: ANDROID_SDK_ROOT could not be resolved. Some commands may fail." >&2
        echo "         Ensure Nix is available or set ANDROID_LOCAL_SDK=1 with a local Android SDK." >&2
      fi
    fi
    # Set empty value to avoid unbound variable errors
    ANDROID_SDK_ROOT=""
  fi

  ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  export ANDROID_SDK_ROOT ANDROID_HOME
  export ANDROID_BUILD_TOOLS_VERSION

  state_home="${ANDROID_USER_HOME:-}"
  if [ -z "$state_home" ]; then
    state_home="${ANDROID_SDK_HOME:-}"
  fi
  if [ -z "$state_home" ]; then
    state_home="${ANDROID_SDK_ROOT:-}"
  fi
  if [ -z "$state_home" ]; then
    # Use virtenv as fallback for state home
    state_home="${ANDROID_EMULATOR_HOME:-}"
  fi
  if [ -z "$state_home" ]; then
    echo "WARNING: ANDROID_USER_HOME could not be determined. AVDs may not be project-local." >&2
    # Continue anyway - some commands don't need AVDs
  fi

  ANDROID_USER_HOME="$state_home"
  ANDROID_SDK_HOME="$state_home"
  ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$state_home/avd}"
  ANDROID_EMULATOR_HOME="${ANDROID_EMULATOR_HOME:-$state_home}"

  unset ANDROID_PREFS_ROOT

  export ANDROID_USER_HOME ANDROID_AVD_HOME ANDROID_EMULATOR_HOME

  mkdir -p "$state_home" "$ANDROID_AVD_HOME" >/dev/null 2>&1 || true

  if android_debug_enabled; then
    android_debug_dump_vars \
      ANDROID_PLUGIN_CONFIG \
      ANDROID_SDK_FLAKE_PATH \
      ANDROID_SDK_FLAKE_OUTPUT \
      ANDROID_LOCAL_SDK \
      ANDROID_SDK_ROOT \
      ANDROID_HOME \
      ANDROID_SDK_HOME \
      ANDROID_USER_HOME \
      ANDROID_AVD_HOME \
      ANDROID_EMULATOR_HOME \
      ANDROID_CONFIG_DIR \
      ANDROID_DEVICES_DIR \
      ANDROID_DEFAULT_DEVICE \
      ANDROID_COMPILE_SDK \
      ANDROID_TARGET_SDK \
      ANDROID_BUILD_TOOLS_VERSION \
      ANDROID_CMDLINE_TOOLS_VERSION
  fi
}

# ============================================================================
# PATH Setup
# ============================================================================

android_setup_path() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    cmdline_tools_bin=""
    if [ -d "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin" ]; then
      cmdline_tools_bin="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    else
      cmdline_tools_dir=$(find "$ANDROID_SDK_ROOT/cmdline-tools" -maxdepth 1 -mindepth 1 -type d -not -name latest 2>/dev/null | sort -V | tail -n 1)
      if [ -n "${cmdline_tools_dir:-}" ] && [ -d "$cmdline_tools_dir/bin" ]; then
        cmdline_tools_bin="$cmdline_tools_dir/bin"
      fi
    fi

    new_path="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools"
    if [ -n "${cmdline_tools_bin:-}" ]; then
      new_path="$new_path:$cmdline_tools_bin"
    fi
    PATH="$new_path:$ANDROID_SDK_ROOT/tools/bin:$PATH"
    export PATH
  fi

  if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -d "${ANDROID_SCRIPTS_DIR}" ]; then
    chmod +x "${ANDROID_SCRIPTS_DIR}/"*.sh >/dev/null 2>&1 || true
    PATH="${ANDROID_SCRIPTS_DIR}:$PATH"
    export PATH
  fi
}

# ============================================================================
# Summary Display
# ============================================================================

android_show_summary() {
  android_sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  android_sdk_version="${ANDROID_BUILD_TOOLS_VERSION:-${ANDROID_CMDLINE_TOOLS_VERSION:-30.0.3}}"
  devices_dir="${ANDROID_DEVICES_DIR:-${ANDROID_CONFIG_DIR:-}/devices}"
  default_device="${ANDROID_DEFAULT_DEVICE:-}"

  if android_debug_enabled; then
    android_debug_dump_vars \
      ANDROID_SDK_ROOT \
      ANDROID_HOME \
      ANDROID_LOCAL_SDK \
      ANDROID_SDK_FLAKE_OUTPUT \
      ANDROID_SYSTEM_IMAGE_TAG \
      ANDROID_BUILD_TOOLS_VERSION \
      ANDROID_CMDLINE_TOOLS_VERSION \
      ANDROID_DEFAULT_DEVICE \
      ANDROID_DEVICES_DIR
  fi

  echo "Resolved Android SDK"
  echo "  ANDROID_SDK_ROOT: ${android_sdk_root:-not set}"
  echo "  ANDROID_BUILD_TOOLS_VERSION: ${android_sdk_version:-30.0.3}"
  echo "  ANDROID_DEVICES_DIR: ${devices_dir:-not set}"
  if [ -n "$default_device" ]; then
    echo "  ANDROID_DEFAULT_DEVICE: ${default_device}"
  fi
  echo "  Tip: use a local SDK with ANDROID_LOCAL_SDK=1 ANDROID_SDK_ROOT=/path/to/sdk (or ANDROID_HOME)."
}

android_debug_log_script "core.sh"
