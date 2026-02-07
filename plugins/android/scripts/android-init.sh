#!/usr/bin/env bash
# Android plugin initialization script
# Generates android.json in virtenv from environment variables for Nix flake evaluation
# This runs before env.sh is sourced

set -e

# Show progress if not in CI (but only once per session)
if [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${ANDROID_INIT_SHOWN:-}" ]; then
  echo "📋 Initializing Android plugin configuration..." >&2
  export ANDROID_INIT_SHOWN=1
fi

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
if ! echo "$json_obj" | jq '.' > "$GENERATED_CONFIG" 2>&1; then
  echo "ERROR: Failed to generate android.json config file" >&2
  echo "       Config JSON: $json_obj" >&2
  exit 1
fi

# ============================================================================
# Generate devices.lock from ANDROID_DEVICES env var
# ============================================================================

DEVICES_DIR="${ANDROID_DEVICES_DIR:-${ANDROID_CONFIG_DIR:-./devbox.d/android}/devices}"
DEVICES_LOCK="${DEVICES_DIR}/devices.lock"

# Skip if devices directory doesn't exist
if [ ! -d "$DEVICES_DIR" ]; then
  exit 0
fi

# Parse ANDROID_DEVICES (comma or space separated, empty = all)
SELECTED_DEVICES="${ANDROID_DEVICES:-}"

# Convert comma-separated to space-separated
SELECTED_DEVICES="$(echo "$SELECTED_DEVICES" | tr ',' ' ')"

# Find matching device files
device_files=()
if [ -z "$SELECTED_DEVICES" ]; then
  # Empty = all devices
  while IFS= read -r file; do
    device_files+=("$file")
  done < <(find "$DEVICES_DIR" -name "*.json" -type f | sort)
else
  # Filter to selected devices
  for selection in $SELECTED_DEVICES; do
    # Try exact filename match first
    if [ -f "${DEVICES_DIR}/${selection}.json" ]; then
      device_files+=("${DEVICES_DIR}/${selection}.json")
    else
      # Try matching by device name field
      while IFS= read -r file; do
        name="$(jq -r '.name // empty' "$file" 2>/dev/null || true)"
        if [ "$name" = "$selection" ]; then
          device_files+=("$file")
          break
        fi
      done < <(find "$DEVICES_DIR" -name "*.json" -type f | sort)
    fi
  done
fi

# Build devices array for lock file
devices_array="["
first=true
for file in "${device_files[@]}"; do
  if [ -f "$file" ]; then
    device_content="$(cat "$file")"
    if [ "$first" = true ]; then
      first=false
    else
      devices_array="${devices_array},"
    fi
    devices_array="${devices_array}${device_content}"
  fi
done
devices_array="${devices_array}]"

# Calculate checksum of all device files (sorted for stability)
if command -v sha256sum >/dev/null 2>&1; then
  checksum="$(find "$DEVICES_DIR" -name "*.json" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | sha256sum | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
  checksum="$(find "$DEVICES_DIR" -name "*.json" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"
else
  checksum=""
fi

# Generate timestamp
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"

# Create devices.lock with jq
if ! echo "$devices_array" | jq \
  --arg cs "$checksum" \
  --arg ts "$timestamp" \
  '{devices: ., checksum: $cs, generated_at: $ts}' \
  > "$DEVICES_LOCK" 2>&1; then
  echo "ERROR: Failed to generate devices.lock file" >&2
  exit 1
fi

# Copy to virtenv for flake to reference
cp "$DEVICES_LOCK" "$VIRTENV_DEVICES_LOCK" 2>/dev/null || true

# Make all scripts executable
SCRIPTS_DIR="${ANDROID_SCRIPTS_DIR:-${VIRTENV_DIR}/scripts}"
if [ -d "$SCRIPTS_DIR" ]; then
  chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true
fi

exit 0
