#!/usr/bin/env bash
# iOS plugin initialization script
# Generates devices.lock from IOS_DEVICES environment variable
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

# Note: ios.json generation removed - all config is now via environment variables

# ============================================================================
# Generate devices.lock from IOS_DEVICES env var
# ============================================================================

DEVICES_DIR="${IOS_DEVICES_DIR:-${IOS_CONFIG_DIR:-./devbox.d/ios}/devices}"
DEVICES_LOCK="${DEVICES_DIR}/devices.lock"

# Skip if devices directory doesn't exist
if [ ! -d "$DEVICES_DIR" ]; then
  exit 0
fi

# Parse IOS_DEVICES (comma or space separated, empty = all)
SELECTED_DEVICES="${IOS_DEVICES:-}"

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
echo "$devices_array" | jq \
  --arg cs "$checksum" \
  --arg ts "$timestamp" \
  '{devices: ., checksum: $cs, generated_at: $ts}' \
  > "$DEVICES_LOCK" 2>/dev/null || exit 0

# Make all scripts executable
SCRIPTS_DIR="${IOS_SCRIPTS_DIR:-${VIRTENV_DIR}/scripts}"
if [ -d "$SCRIPTS_DIR" ]; then
  chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true
fi

exit 0
