#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
Usage: android.sh <command> [args]

Commands:
  devices <command> [args]
  config show
  config set key=value [key=value...]
  config reset

Examples:
  android.sh devices list
  android.sh devices create pixel_api28 --api 28 --device pixel --tag google_apis
  android.sh config set ANDROID_DEFAULT_DEVICE=max
USAGE
  exit 1
}

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
config_path="${config_dir%/}/android.json"

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    exit 1
  fi
}

case "$command_name" in
  devices)
    exec "${ANDROID_SCRIPTS_DIR:-${config_dir%/}/scripts}/devices.sh" "$@"
    ;;
  config)
    sub="${1-}"
    shift || true
    require_jq
    case "$sub" in
      show)
        cat "$config_path"
        ;;
      set)
        [ "${1-}" != "" ] || usage
        tmp="${config_path}.tmp"
        filter='.'
        while [ "${1-}" != "" ]; do
          pair="$1"
          key="${pair%%=*}"
          value="${pair#*=}"
          if [ -z "$key" ] || [ "$key" = "$value" ]; then
            echo "Invalid key=value: $pair" >&2
            exit 1
          fi
          if ! jq -e --arg key "$key" 'has($key)' "$config_path" >/dev/null 2>&1; then
            echo "Unknown config key: $key" >&2
            exit 1
          fi
          filter="$filter | .${key} = \"${value}\""
          shift
        done
        jq "$filter" "$config_path" >"$tmp"
        mv "$tmp" "$config_path"
        ;;
      reset)
        default_config="${config_dir%/}/config/android.json"
        if [ ! -f "$default_config" ]; then
          default_config="${config_dir%/}/android.json"
        fi
        if [ ! -f "$default_config" ]; then
          echo "Default Android config not found under ${config_dir%/}/config" >&2
          exit 1
        fi
        cp "$default_config" "$config_path"
        ;;
      *)
        usage
        ;;
    esac
    ;;
  *)
    usage
    ;;
esac
