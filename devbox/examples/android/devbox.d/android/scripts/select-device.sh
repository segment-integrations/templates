#!/usr/bin/env sh
set -eu

if [ "${1-}" = "" ]; then
  echo "Usage: select-device.sh <device-name> [device-name...]" >&2
  exit 1
fi

config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
config_path="${config_dir%/}/android.json"

if [ ! -f "$config_path" ]; then
  echo "Android config not found: $config_path" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to update $config_path" >&2
  exit 1
fi

tmp="${config_path}.tmp"
jq --argjson selections "$(printf '%s\n' "$@" | jq -R . | jq -s .)" '.EVALUATE_DEVICES = $selections' "$config_path" >"$tmp"

mv "$tmp" "$config_path"

echo "Selected Android devices: $*"
