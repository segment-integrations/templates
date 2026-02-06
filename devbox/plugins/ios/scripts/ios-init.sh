#!/usr/bin/env bash
# iOS plugin initialization script
# Generates ios.json in virtenv from environment variables
# This runs before env.sh is sourced

set -e

# Find virtenv directory
VIRTENV_DIR="${IOS_SCRIPTS_DIR:-}/.."
if [ -z "$VIRTENV_DIR" ] || [ "$VIRTENV_DIR" = "/.." ]; then
  # Fallback if IOS_SCRIPTS_DIR not set
  VIRTENV_DIR=".devbox/virtenv/ios"
fi

# Require jq
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Create virtenv directory
mkdir -p "$VIRTENV_DIR" 2>/dev/null || exit 0

# Generate ios.json from environment variables
GENERATED_CONFIG="${VIRTENV_DIR}/ios.json"

# List of config keys to include in generated JSON
CONFIG_KEYS=(
  "EVALUATE_DEVICES"
  "IOS_DEFAULT_DEVICE"
  "IOS_DEFAULT_RUNTIME"
  "IOS_APP_PROJECT"
  "IOS_APP_SCHEME"
  "IOS_APP_BUNDLE_ID"
  "IOS_APP_ARTIFACT"
  "IOS_APP_DERIVED_DATA"
  "IOS_DEVELOPER_DIR"
  "IOS_DOWNLOAD_RUNTIME"
  "IOS_XCODE_ENV_PATH"
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

exit 0
