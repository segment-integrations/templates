#!/usr/bin/env sh
set -eu

if [ "${1-}" = "" ]; then
  echo "Usage: select-device.sh <device-name> [device-name...]" >&2
  exit 1
fi

config_dir="${IOS_CONFIG_DIR:-./devbox.d/ios}"
config_path="${config_dir%/}/ios.json"

if [ ! -f "$config_path" ]; then
  echo "iOS config not found: $config_path" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to update $config_path" >&2
  exit 1
fi

tmp="${config_path}.tmp"
jq --argjson selections "$(printf '%s\n' "$@" | jq -R . | jq -s .)" '.EVALUATE_DEVICES = $selections' "$config_path" >"$tmp"

mv "$tmp" "$config_path"

echo "Selected iOS devices: $*"
