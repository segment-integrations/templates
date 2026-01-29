#!/usr/bin/env sh

if ! (return 0 2>/dev/null); then
  echo "devbox.d/android/scripts/env.sh must be sourced." >&2
  exit 1
fi

if [ "${ANDROID_ENV_LOADED:-}" = "1" ] && [ "${ANDROID_ENV_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_ENV_LOADED=1
ANDROID_ENV_LOADED_PID="$$"

android_debug_enabled() {
  [ "${ANDROID_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]
}

android_debug_log() {
  if android_debug_enabled; then
    printf '%s\n' "DEBUG: $*"
  fi
}

android_debug_log_script() {
  if android_debug_enabled; then
    if (return 0 2>/dev/null); then
      context="sourced"
    else
      context="run"
    fi
    android_debug_log "$1 ($context)"
  fi
}

android_require_tool() {
  tool="$1"
  message="${2:-Missing required tool: $tool. Ensure the Devbox shell is active and required packages are installed.}"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$message" >&2
    exit 1
  fi
}

android_require_dir_contains() {
  base="$1"
  subpath="$2"
  message="${3:-Missing required path: $base/$subpath.}"
  if [ ! -e "$base/$subpath" ]; then
    echo "$message" >&2
    exit 1
  fi
}

android_debug_dump_vars() {
  if android_debug_enabled; then
    for var in "$@"; do
      value="$(eval "printf '%s' \"\${$var-}\"")"
      printf 'DEBUG: %s=%s\n' "$var" "$value"
    done
  fi
}

load_android_config() {
  config_path="${ANDROID_PLUGIN_CONFIG:-}"
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  plugin_root="$(cd "$script_dir/.." && pwd)"
  if [ -z "$config_path" ]; then
    if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -f "${DEVBOX_PROJECT_ROOT}/devbox.d/android/android.json" ]; then
      config_path="${DEVBOX_PROJECT_ROOT}/devbox.d/android/android.json"
    elif [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -f "${DEVBOX_PROJECT_DIR}/devbox.d/android/android.json" ]; then
      config_path="${DEVBOX_PROJECT_DIR}/devbox.d/android/android.json"
    elif [ -n "${DEVBOX_WD:-}" ] && [ -f "${DEVBOX_WD}/devbox.d/android/android.json" ]; then
      config_path="${DEVBOX_WD}/devbox.d/android/android.json"
    elif [ -f "${plugin_root}/android.json" ]; then
      config_path="${plugin_root}/android.json"
    else
      config_path="./devbox.d/android/android.json"
    fi
  fi

  if [ ! -f "$config_path" ]; then
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to read ${config_path}. Ensure the Devbox Android plugin packages are installed." >&2
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

  if android_debug_enabled; then
    android_debug_log "Loaded Android plugin config: $config_path"
  fi
}

load_android_config

resolve_flake_sdk_root() {
  output="$1"
  if ! command -v nix >/dev/null 2>&1; then
    return 1
  fi
  root="${ANDROID_SDK_FLAKE_PATH:-}"
  if [ -z "$root" ]; then
    if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -d "${DEVBOX_PROJECT_ROOT}/devbox.d/android" ]; then
      root="${DEVBOX_PROJECT_ROOT}/devbox.d/android"
    elif [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -d "${DEVBOX_PROJECT_DIR}/devbox.d/android" ]; then
      root="${DEVBOX_PROJECT_DIR}/devbox.d/android"
    elif [ -n "${DEVBOX_WD:-}" ] && [ -d "${DEVBOX_WD}/devbox.d/android" ]; then
      root="${DEVBOX_WD}/devbox.d/android"
    elif [ -n "${plugin_root:-}" ] && [ -f "${plugin_root}/flake.nix" ]; then
      root="$plugin_root"
    else
      root="./devbox.d/android"
    fi
    ANDROID_SDK_FLAKE_PATH="$root"
    export ANDROID_SDK_FLAKE_PATH
  fi
  if android_debug_enabled; then
    android_debug_log "Android SDK flake path: ${ANDROID_SDK_FLAKE_PATH:-$root}"
  fi
  sdk_out=$(
    nix --extra-experimental-features 'nix-command flakes' \
      eval --raw "path:${root}#${output}.outPath" 2>/dev/null || true
  )
  if [ -n "${sdk_out:-}" ] && [ -d "$sdk_out/libexec/android-sdk" ]; then
    printf '%s\n' "$sdk_out/libexec/android-sdk"
    return 0
  fi
  return 1
}

detect_sdk_root_from_sdkmanager() {
  sm="$(command -v sdkmanager 2>/dev/null || true)"
  if [ -z "$sm" ]; then
    return 1
  fi
  if command -v readlink >/dev/null 2>&1; then
    sm="$(readlink "$sm" 2>/dev/null || printf '%s' "$sm")"
  fi
  sm_dir="$(cd "$(dirname "$sm")" && pwd)"
  candidates="${sm_dir}/.. ${sm_dir}/../share/android-sdk ${sm_dir}/../libexec/android-sdk ${sm_dir}/../.."
  for c in $candidates; do
    if [ -d "$c/platform-tools" ] || [ -d "$c/platforms" ] || [ -d "$c/system-images" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

prefer_local="${ANDROID_LOCAL_SDK:-}"
case "$prefer_local" in
  1 | true | TRUE | yes | YES | on | ON)
    prefer_local=1
    ;;
  *)
    prefer_local=""
    ;;
esac

if [ -z "${ANDROID_SDK_FLAKE_OUTPUT:-}" ]; then
  ANDROID_SDK_FLAKE_OUTPUT="android-sdk"
  export ANDROID_SDK_FLAKE_OUTPUT
fi

if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -n "${ANDROID_HOME:-}" ]; then
  ANDROID_SDK_ROOT="$ANDROID_HOME"
fi

if [ -n "$prefer_local" ]; then
  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    detected_root="$(detect_sdk_root_from_sdkmanager 2>/dev/null || true)"
    if [ -n "$detected_root" ]; then
      ANDROID_SDK_ROOT="$detected_root"
    fi
  fi
else
  resolved_root="$(resolve_flake_sdk_root "$ANDROID_SDK_FLAKE_OUTPUT" 2>/dev/null || true)"
  if [ -n "$resolved_root" ]; then
    ANDROID_SDK_ROOT="$resolved_root"
  fi
fi

if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  echo "ANDROID_SDK_ROOT/ANDROID_HOME must be set. Enable the Devbox Android SDK package or set ANDROID_SDK_ROOT explicitly." >&2
  exit 1
fi

ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT ANDROID_HOME
export ANDROID_BUILD_TOOLS_VERSION

if [ -z "${ANDROID_SDK_HOME:-}" ]; then
  echo "ANDROID_SDK_HOME is not set. Enable the local Devbox Android plugin to keep AVDs project-local." >&2
  exit 1
fi

if [ -z "${ANDROID_USER_HOME:-}" ]; then
  ANDROID_USER_HOME="$ANDROID_SDK_HOME"
fi

if [ -z "${ANDROID_AVD_HOME:-}" ]; then
  ANDROID_AVD_HOME="$ANDROID_SDK_HOME/avd"
fi

if [ -z "${ANDROID_EMULATOR_HOME:-}" ]; then
  ANDROID_EMULATOR_HOME="$ANDROID_SDK_HOME"
fi

export ANDROID_SDK_HOME ANDROID_USER_HOME ANDROID_AVD_HOME ANDROID_EMULATOR_HOME

mkdir -p "$ANDROID_SDK_HOME" "$ANDROID_AVD_HOME" >/dev/null 2>&1 || true

if android_debug_enabled; then
  android_debug_dump_vars \
    ANDROID_PLUGIN_CONFIG \
    ANDROID_SDK_FLAKE_PATH \
    ANDROID_SDK_FLAKE_OUTPUT \
    ANDROID_LOCAL_SDK \
    ANDROID_SDK_ROOT \
    ANDROID_HOME \
    ANDROID_SDK_HOME \
    ANDROID_USER_HOME \
    ANDROID_AVD_HOME \
    ANDROID_EMULATOR_HOME \
    ANDROID_BUILD_TOOLS_VERSION \
    ANDROID_CMDLINE_TOOLS_VERSION \
    ANDROID_MIN_API \
    ANDROID_MAX_API \
    ANDROID_CUSTOM_API \
    ANDROID_MIN_DEVICE \
    ANDROID_MAX_DEVICE
fi

if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
  cmdline_tools_bin=""
  if [ -d "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin" ]; then
    cmdline_tools_bin="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
  else
    cmdline_tools_dir=$(find "$ANDROID_SDK_ROOT/cmdline-tools" -maxdepth 1 -mindepth 1 -type d -not -name latest 2>/dev/null | sort -V | tail -n 1)
    if [ -n "${cmdline_tools_dir:-}" ] && [ -d "$cmdline_tools_dir/bin" ]; then
      cmdline_tools_bin="$cmdline_tools_dir/bin"
    fi
  fi

  new_path="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools"
  if [ -n "${cmdline_tools_bin:-}" ]; then
    new_path="$new_path:$cmdline_tools_bin"
  fi
  PATH="$new_path:$ANDROID_SDK_ROOT/tools/bin:$PATH"
  export PATH
fi

android_debug_log_script "devbox.d/android/scripts/env.sh"

if [ -n "${INIT_ANDROID:-}" ] && [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${ANDROID_SDK_SUMMARY_PRINTED:-}" ]; then
  ANDROID_SDK_SUMMARY_PRINTED=1
  export ANDROID_SDK_SUMMARY_PRINTED

  android_sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  android_sdk_version="${ANDROID_BUILD_TOOLS_VERSION:-${ANDROID_CMDLINE_TOOLS_VERSION:-30.0.3}}"
  android_min_api="${ANDROID_MIN_API:-21}"
  android_max_api="${ANDROID_MAX_API:-33}"
  android_system_image_tag="${ANDROID_CUSTOM_SYSTEM_IMAGE_TAG:-${ANDROID_SYSTEM_IMAGE_TAG:-google_apis}}"
  android_system_image_abi=""
  android_target_api="${AVD_API:-${ANDROID_TARGET_API:-}}"
  android_target_source=""
  if [ -z "$android_target_api" ]; then
    case "${TARGET_SDK:-max}" in
      min)
        android_target_api="$android_min_api"
        android_target_source="min"
        ;;
      max)
        android_target_api="$android_max_api"
        android_target_source="max"
        ;;
      custom)
        android_target_api="${ANDROID_CUSTOM_API:-}"
        android_target_source="custom"
        ;;
      *)
        android_target_api="$android_max_api"
        android_target_source="max"
        ;;
    esac
  elif [ -n "${AVD_API:-}" ]; then
    android_target_source="avd"
  elif [ -n "${ANDROID_TARGET_API:-}" ]; then
    android_target_source="target"
  fi

  android_target_device="${AVD_DEVICE:-}"
  if [ -z "$android_target_device" ]; then
    case "${TARGET_SDK:-max}" in
      min) android_target_device="${ANDROID_MIN_DEVICE:-}" ;;
      max) android_target_device="${ANDROID_MAX_DEVICE:-}" ;;
      custom) android_target_device="${ANDROID_CUSTOM_DEVICE:-}" ;;
    esac
  fi

  candidates=""
  if [ -n "$android_sdk_root" ] && [ -n "$android_system_image_tag" ]; then
    host_arch="$(uname -m)"
    if [ "$host_arch" = "arm64" ] || [ "$host_arch" = "aarch64" ]; then
      candidates="arm64-v8a x86_64 x86"
    else
      candidates="x86_64 x86 arm64-v8a"
    fi
  fi

  if [ -n "$android_sdk_root" ] && [ -n "$android_target_api" ] && [ -n "$android_system_image_tag" ]; then
    for abi in $candidates; do
      if [ -d "$android_sdk_root/system-images/android-${android_target_api}/${android_system_image_tag}/${abi}" ]; then
        android_system_image_abi="$abi"
        break
      fi
    done
  fi

  if [ -n "$android_system_image_abi" ]; then
    android_system_image_summary="${android_system_image_tag};${android_system_image_abi}"
  else
    android_system_image_summary="$android_system_image_tag"
  fi
  if [ -n "$android_target_device" ]; then
    android_system_image_summary="${android_system_image_summary} (${android_target_device})"
  fi

  if android_debug_enabled; then
    android_debug_dump_vars \
      ANDROID_SDK_ROOT \
      ANDROID_HOME \
      ANDROID_LOCAL_SDK \
      ANDROID_SDK_FLAKE_OUTPUT \
      ANDROID_MIN_API \
      ANDROID_MAX_API \
      TARGET_SDK \
      ANDROID_TARGET_API \
      ANDROID_SYSTEM_IMAGE_TAG \
      ANDROID_BUILD_TOOLS_VERSION \
      ANDROID_CMDLINE_TOOLS_VERSION
  fi

  echo "Resolved Android SDK"
  echo "  ANDROID_SDK_ROOT: ${android_sdk_root:-not set}"
  echo "  ANDROID_BUILD_TOOLS_VERSION: ${android_sdk_version:-30.0.3}"
  echo "  ANDROID_AVD_TARGET: api=${android_target_api:-not set} device=${android_target_device:-unknown} image=${android_system_image_summary:-google_apis}"
  echo "  Tip: use a local SDK with ANDROID_LOCAL_SDK=1 ANDROID_SDK_ROOT=/path/to/sdk (or ANDROID_HOME)."
fi
