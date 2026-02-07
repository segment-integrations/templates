#!/usr/bin/env bash
# Android Plugin - Setup and Environment Initialization
#wh
# Execution modes:
# 1. bash setup.sh   - Generates config files (android.json, devices.lock)
# 2. . setup.sh      - Initializes environment (sources core.sh, runs validation)

# ============================================================================
# Detect Execution Mode
# ============================================================================

if (return 0 2>/dev/null); then
  SOURCED=true
else
  SOURCED=false
fi

# ============================================================================
# Part 1: Config File Generation (executed mode only)
# ============================================================================

if [ "$SOURCED" = false ]; then
  set -e

  # Show progress if not in CI
  if [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${ANDROID_INIT_SHOWN:-}" ]; then
    echo "📋 Initializing Android plugin configuration..." >&2
    export ANDROID_INIT_SHOWN=1
  fi

  # Find virtenv directory
  VIRTENV_DIR="${ANDROID_SCRIPTS_DIR:-}/.."
  if [ -z "$VIRTENV_DIR" ] || [ "$VIRTENV_DIR" = "/.." ]; then
    VIRTENV_DIR=".devbox/virtenv/android"
  fi

  # Require jq
  if ! command -v jq >/dev/null 2>&1; then
    exit 0
  fi

  # Create virtenv directory
  mkdir -p "$VIRTENV_DIR" 2>/dev/null || exit 0

  # Generate android.json from environment variables
  GENERATED_CONFIG="${VIRTENV_DIR}/android.json"
  VIRTENV_DEVICES_LOCK="${VIRTENV_DIR}/devices.lock.json"

  CONFIG_KEYS=(
    "ANDROID_LOCAL_SDK"
    "ANDROID_COMPILE_SDK"
    "ANDROID_TARGET_SDK"
    "ANDROID_DEFAULT_DEVICE"
    "ANDROID_SYSTEM_IMAGE_TAG"
    "ANDROID_APP_APK"
    "ANDROID_BUILD_TOOLS_VERSION"
    "ANDROID_INCLUDE_NDK"
    "ANDROID_NDK_VERSION"
    "ANDROID_INCLUDE_CMAKE"
    "ANDROID_CMAKE_VERSION"
    "ANDROID_CMDLINE_TOOLS_VERSION"
  )

  # Build JSON from env vars
  json_obj="{"
  first=true

  for key in "${CONFIG_KEYS[@]}"; do
    env_value="$(eval echo "\${${key}:-}")"
    [ -z "$env_value" ] && continue

    [ "$first" = false ] && json_obj="${json_obj},"
    first=false

    if [ "$env_value" = "true" ] || [ "$env_value" = "false" ]; then
      json_obj="${json_obj}\"${key}\":${env_value}"
    elif [ "$env_value" -eq "$env_value" ] 2>/dev/null; then
      json_obj="${json_obj}\"${key}\":${env_value}"
    else
      escaped_value="${env_value//\"/\\\"}"
      json_obj="${json_obj}\"${key}\":\"${escaped_value}\""
    fi
  done

  json_obj="${json_obj}}"

  echo "$json_obj" | jq '.' > "$GENERATED_CONFIG" 2>&1 || {
    echo "ERROR: Failed to generate android.json" >&2
    exit 1
  }

  # Generate devices.lock
  DEVICES_DIR="${ANDROID_DEVICES_DIR:-${ANDROID_CONFIG_DIR:-./devbox.d/android}/devices}"
  DEVICES_LOCK="${DEVICES_DIR}/devices.lock"

  if [ -d "$DEVICES_DIR" ]; then
    SELECTED_DEVICES="$(echo "${ANDROID_DEVICES:-}" | tr ',' ' ')"

    device_files=()
    if [ -z "$SELECTED_DEVICES" ]; then
      while IFS= read -r file; do
        device_files+=("$file")
      done < <(find "$DEVICES_DIR" -name "*.json" -type f | sort)
    else
      for selection in $SELECTED_DEVICES; do
        if [ -f "${DEVICES_DIR}/${selection}.json" ]; then
          device_files+=("${DEVICES_DIR}/${selection}.json")
        else
          while IFS= read -r file; do
            name="$(jq -r '.name // empty' "$file" 2>/dev/null || true)"
            [ "$name" = "$selection" ] && device_files+=("$file") && break
          done < <(find "$DEVICES_DIR" -name "*.json" -type f | sort)
        fi
      done
    fi

    devices_array="["
    first=true
    for file in "${device_files[@]}"; do
      if [ -f "$file" ]; then
        [ "$first" = false ] && devices_array="${devices_array},"
        first=false
        devices_array="${devices_array}$(cat "$file")"
      fi
    done
    devices_array="${devices_array}]"

    if command -v sha256sum >/dev/null 2>&1; then
      checksum="$(find "$DEVICES_DIR" -name "*.json" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | sha256sum | cut -d' ' -f1)"
    elif command -v shasum >/dev/null 2>&1; then
      checksum="$(find "$DEVICES_DIR" -name "*.json" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"
    else
      checksum=""
    fi

    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"

    echo "$devices_array" | jq \
      --arg cs "$checksum" \
      --arg ts "$timestamp" \
      '{devices: ., checksum: $cs, generated_at: $ts}' \
      > "$DEVICES_LOCK" 2>&1 && cp "$DEVICES_LOCK" "$VIRTENV_DEVICES_LOCK" 2>/dev/null || true
  fi

  # Make scripts executable
  SCRIPTS_DIR="${ANDROID_SCRIPTS_DIR:-${VIRTENV_DIR}/scripts}"
  [ -d "$SCRIPTS_DIR" ] && find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

  exit 0
fi

# ============================================================================
# Part 2: Environment Initialization (sourced mode only)
# ============================================================================

# Prevent double-loading
if [ "${ANDROID_ENV_LOADED:-}" = "1" ] && [ "${ANDROID_ENV_LOADED_PID:-}" = "$$" ]; then
  return 0
fi
ANDROID_ENV_LOADED=1
ANDROID_ENV_LOADED_PID="$$"
export ANDROID_ENV_LOADED ANDROID_ENV_LOADED_PID

set -eu

# Source core.sh which handles SDK resolution, PATH setup, etc.
# core.sh will automatically source lib.sh as a dependency
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/platform/core.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/platform/core.sh"

  # Setup SDK and PATH (functions from core.sh)
  android_setup_sdk_environment
  android_setup_path

  # Optional validation
  if [ -f "${ANDROID_SCRIPTS_DIR}/domain/validate.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/domain/validate.sh"
    android_validate_sdk || true
  fi

  # Optional summary display
  if [ -n "${INIT_ANDROID:-}" ] && [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${ANDROID_SDK_SUMMARY_PRINTED:-}" ]; then
    ANDROID_SDK_SUMMARY_PRINTED=1
    export ANDROID_SDK_SUMMARY_PRINTED
    android_show_summary
  fi
fi
