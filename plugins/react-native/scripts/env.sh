#!/usr/bin/env sh
# React Native Plugin - Environment Setup
# See REFERENCE.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: env.sh must be sourced" >&2
  exit 1
fi

if [ "${REACT_NATIVE_ENV_LOADED:-}" = "1" ] && [ "${REACT_NATIVE_ENV_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
REACT_NATIVE_ENV_LOADED=1
REACT_NATIVE_ENV_LOADED_PID="$$"

# Source lib.sh
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${REACT_NATIVE_SCRIPTS_DIR:-}" ] && [ -d "${REACT_NATIVE_SCRIPTS_DIR}" ]; then
  script_dir="${REACT_NATIVE_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

# Load React Native configuration
load_react_native_config() {
  config_path="${REACT_NATIVE_PLUGIN_CONFIG:-}"
  if [ -z "$config_path" ]; then
    config_path="$(react_native_config_path 2>/dev/null || echo "")"
  fi

  if [ -z "$config_path" ] || [ ! -f "$config_path" ]; then
    return 0
  fi

  react_native_require_jq

  tab="$(printf '\t')"
  while IFS="$tab" read -r key value; do
    if [ -z "$key" ] || [ "$value" = "null" ]; then
      continue
    fi
    current="$(eval "printf '%s' \"\${$key-}\"")"
    if [ -z "$current" ] && [ -n "$value" ]; then
      eval "$key=\"\$value\""
      # shellcheck disable=SC2163
      export "$key"
    fi
  done <<EOF
$(jq -r 'to_entries[] | "\(.key)\t\(.value|tostring)"' "$config_path")
EOF
}

load_react_native_config

react_native_debug_log "env.sh loaded"
