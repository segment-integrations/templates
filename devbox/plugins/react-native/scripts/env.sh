#!/usr/bin/env sh

if ! (return 0 2>/dev/null); then
  echo "devbox.d/react-native/scripts/env.sh must be sourced." >&2
  exit 1
fi

if [ "${REACT_NATIVE_ENV_LOADED:-}" = "1" ] && [ "${REACT_NATIVE_ENV_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
REACT_NATIVE_ENV_LOADED=1
REACT_NATIVE_ENV_LOADED_PID="$$"

load_react_native_config() {
  config_path="${REACT_NATIVE_PLUGIN_CONFIG:-}"
  if [ -z "$config_path" ]; then
    if [ -n "${REACT_NATIVE_CONFIG_DIR:-}" ] && [ -f "${REACT_NATIVE_CONFIG_DIR}/react-native.json" ]; then
      config_path="${REACT_NATIVE_CONFIG_DIR}/react-native.json"
    elif [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -f "${DEVBOX_PROJECT_ROOT}/devbox.d/react-native/react-native.json" ]; then
      config_path="${DEVBOX_PROJECT_ROOT}/devbox.d/react-native/react-native.json"
    elif [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -f "${DEVBOX_PROJECT_DIR}/devbox.d/react-native/react-native.json" ]; then
      config_path="${DEVBOX_PROJECT_DIR}/devbox.d/react-native/react-native.json"
    elif [ -n "${DEVBOX_WD:-}" ] && [ -f "${DEVBOX_WD}/devbox.d/react-native/react-native.json" ]; then
      config_path="${DEVBOX_WD}/devbox.d/react-native/react-native.json"
    else
      config_path="./devbox.d/react-native/react-native.json"
    fi
  fi

  if [ ! -f "$config_path" ]; then
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to read ${config_path}. Ensure the Devbox React Native plugin packages are installed." >&2
    exit 1
  fi

  tab="$(printf '\t')"
  while IFS="$tab" read -r key value; do
    if [ -z "$key" ] || [ "$value" = "null" ]; then
      continue
    fi
    current="$(eval "printf '%s' \"\${$key-}\"")"
    if [ -z "$current" ] && [ -n "$value" ]; then
      eval "$key=\"\$value\""
      export "$key"
    fi
  done <<EOF
$(jq -r 'to_entries[] | "\(.key)\t\(.value|tostring)"' "$config_path")
EOF
}

load_react_native_config
