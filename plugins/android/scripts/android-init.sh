#!/usr/bin/env bash
# Android plugin initialization script
# Generates android.json in virtenv from environment variables for Nix flake evaluation
# This runs before env.sh is sourced

set -e

# Find virtenv directory
VIRTENV_DIR="${ANDROID_SCRIPTS_DIR:-}/.."
if [ -z "$VIRTENV_DIR" ] || [ "$VIRTENV_DIR" = "/.." ]; then
  # Fallback if ANDROID_SCRIPTS_DIR not set
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

# List of config keys to include in generated JSON
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

# Build JSON object from env vars
json_obj="{"
first=true

for key in "${CONFIG_KEYS[@]}"; do
  env_value="$(eval echo "\${${key}:-}")"

  # Skip if env var not set
  if [ -z "$env_value" ]; then
    continue
  fi

  # Add comma separator for non-first items
  if [ "$first" = false ]; then
    json_obj="${json_obj},"
  fi
  first=false

  # Add key-value pair with proper type handling
  if [ "$env_value" = "true" ] || [ "$env_value" = "false" ]; then
    # Boolean
    json_obj="${json_obj}\"${key}\":${env_value}"
  elif [ "$env_value" -eq "$env_value" ] 2>/dev/null; then
    # Number
    json_obj="${json_obj}\"${key}\":${env_value}"
  else
    # String - escape quotes
    escaped_value="${env_value//\"/\\\"}"
    json_obj="${json_obj}\"${key}\":\"${escaped_value}\""
  fi
done

json_obj="${json_obj}}"

# Write generated config and format with jq
echo "$json_obj" | jq '.' > "$GENERATED_CONFIG" 2>/dev/null || exit 0

# Copy devices.lock from devbox.d to virtenv for flake to reference
SOURCE_DEVICES_LOCK="${ANDROID_DEVICES_DIR:-./devbox.d/android/devices}/devices.lock"
if [ -f "$SOURCE_DEVICES_LOCK" ]; then
  cp "$SOURCE_DEVICES_LOCK" "$VIRTENV_DEVICES_LOCK"
fi

exit 0
