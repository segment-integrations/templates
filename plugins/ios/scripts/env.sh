#!/usr/bin/env sh

if ! (return 0 2>/dev/null); then
  echo "templates/devbox/plugins/ios/scripts/env.sh must be sourced." >&2
  exit 1
fi

if [ "${IOS_ENV_LOADED:-}" = "1" ] && [ "${IOS_ENV_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_ENV_LOADED=1
IOS_ENV_LOADED_PID="$$"

# Temporarily define script_dir for sourcing lib.sh
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# Source lib.sh first
# shellcheck disable=SC1090
. "$script_dir/lib.sh"

ios_debug_enabled() {
  [ "${IOS_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]
}

ios_debug_log() {
  if ios_debug_enabled; then
    printf '%s\n' "DEBUG: $*" >&2
  fi
}

ios_debug_log_script() {
  if ios_debug_enabled; then
    if (return 0 2>/dev/null); then
      context="sourced"
    else
      context="run"
    fi
    ios_debug_log "$1 ($context)"
  fi
}

ios_debug_dump_vars() {
  if ios_debug_enabled; then
    for var in "$@"; do
      value="$(eval "printf '%s' \"\${$var-}\"")"
      printf 'DEBUG: %s=%s\n' "$var" "$value"
    done
  fi
}

ios_require_tool() {
  tool="$1"
  message="${2:-Missing required tool: $tool. Ensure the Devbox shell is active and required packages are installed.}"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$message" >&2
    exit 1
  fi
}

ios_require_dir() {
  path="$1"
  message="${2:-Missing required directory: $path.}"
  if [ ! -d "$path" ]; then
    echo "$message" >&2
    exit 1
  fi
}

ios_require_dir_contains() {
  base="$1"
  subpath="$2"
  message="${3:-Missing required path: $base/$subpath.}"
  if [ ! -e "$base/$subpath" ]; then
    echo "$message" >&2
    exit 1
  fi
}

# Add macOS system tools to PATH for pure environments
# Only on macOS - needed for xcode-select, xcrun, etc.
if [ "$(uname -s)" = "Darwin" ]; then
  PATH="/usr/bin:${PATH}"
  export PATH
  ios_debug_log "Added /usr/bin to PATH for macOS system tools"
fi

load_ios_config() {
  # Config is generated from env vars by ios-init.sh in virtenv
  # We just need to ensure all env vars are exported
  # This function is now a no-op since env vars are the source of truth
  # and are already set by the plugin's env section

  if ios_debug_enabled; then
    ios_debug_log "iOS config loaded from environment variables"
  fi
}

load_ios_config

# Source and run validation (non-blocking)
if [ -f "${IOS_SCRIPTS_DIR}/validate.sh" ]; then
  . "${IOS_SCRIPTS_DIR}/validate.sh"
  ios_validate_xcode || true
  # devices.lock validation removed - auto-generated on every shell init
fi

if [ -z "${IOS_NODE_BINARY:-}" ] && command -v node >/dev/null 2>&1; then
  IOS_NODE_BINARY="$(command -v node)"
  export IOS_NODE_BINARY
fi

ios_resolve_devbox_bin() {
  if [ -n "${DEVBOX_BIN:-}" ] && [ -x "$DEVBOX_BIN" ]; then
    printf '%s\n' "$DEVBOX_BIN"
    return 0
  fi
  if command -v devbox >/dev/null 2>&1; then
    command -v devbox
    return 0
  fi
  if [ -n "${DEVBOX_INIT_PATH:-}" ]; then
    devbox_bin="$(PATH="$DEVBOX_INIT_PATH:$PATH" command -v devbox 2>/dev/null || true)"
    if [ -n "$devbox_bin" ]; then
      DEVBOX_BIN="$devbox_bin"
      export DEVBOX_BIN
      printf '%s\n' "$devbox_bin"
      return 0
    fi
  fi
  for candidate in "$HOME/.nix-profile/bin/devbox" "/usr/local/bin/devbox" "/opt/homebrew/bin/devbox"; do
    if [ -x "$candidate" ]; then
      DEVBOX_BIN="$candidate"
      export DEVBOX_BIN
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

ios_latest_xcode_dev_dir() {
  entries=""
  for app in /Applications/Xcode*.app /Applications/Xcode.app; do
    [ -d "$app/Contents/Developer" ] || continue
    version="0"
    if [ -x /usr/libexec/PlistBuddy ] && [ -f "$app/Contents/Info.plist" ]; then
      version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null || printf '0')"
    fi
    entries="${entries}${version}|${app}/Contents/Developer
"
  done
  if [ -n "$entries" ]; then
    printf '%s' "$entries" | sort -Vr | head -n1 | cut -d'|' -f2
  fi
}

ios_resolve_developer_dir() {
  desired="${IOS_DEVELOPER_DIR:-}"
  if [ -n "$desired" ] && [ -d "$desired" ]; then
    printf '%s\n' "$desired"
    return 0
  fi

  desired="$(ios_latest_xcode_dev_dir 2>/dev/null || true)"
  if [ -n "$desired" ] && [ -d "$desired" ]; then
    printf '%s\n' "$desired"
    return 0
  fi

  if command -v xcode-select >/dev/null 2>&1; then
    desired="$(xcode-select -p 2>/dev/null || true)"
    if [ -n "$desired" ] && [ -d "$desired" ]; then
      printf '%s\n' "$desired"
      return 0
    fi
  fi

  if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    printf '%s\n' "/Applications/Xcode.app/Contents/Developer"
    return 0
  fi

  return 1
}

devbox_omit_nix_env() {
  if [ "${DEVBOX_OMIT_NIX_ENV_APPLIED:-}" = "1" ]; then
    return 0
  fi

  export DEVBOX_OMIT_NIX_ENV_APPLIED=1
  devbox_bin="$(ios_resolve_devbox_bin 2>/dev/null || true)"
  if [ -z "$devbox_bin" ]; then
    ios_debug_log "devbox not found; skipping omit-nix-env setup."
    return 0
  fi

  devbox_init_path="${DEVBOX_INIT_PATH:-}"
  devbox_bin_dir="$(dirname "$devbox_bin")"
  devbox_project_bin=""
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -d "${DEVBOX_PROJECT_ROOT}/.devbox/bin" ]; then
    devbox_project_bin="${DEVBOX_PROJECT_ROOT}/.devbox/bin"
  elif [ -n "${DEVBOX_WD:-}" ] && [ -d "${DEVBOX_WD}/.devbox/bin" ]; then
    devbox_project_bin="${DEVBOX_WD}/.devbox/bin"
  fi

  devbox_config_path=""
  if [ -n "${DEVBOX_CONFIG:-}" ] && [ -f "$DEVBOX_CONFIG" ]; then
    devbox_config_path="$DEVBOX_CONFIG"
  elif [ -n "${DEVBOX_CONFIG_PATH:-}" ] && [ -f "$DEVBOX_CONFIG_PATH" ]; then
    devbox_config_path="$DEVBOX_CONFIG_PATH"
  elif [ -n "${DEVBOX_CONFIG_DIR:-}" ] && [ -f "${DEVBOX_CONFIG_DIR%/}/devbox.json" ]; then
    devbox_config_path="${DEVBOX_CONFIG_DIR%/}/devbox.json"
  fi

  if [ -n "$devbox_config_path" ]; then
    eval "$("$devbox_bin" --config "$devbox_config_path" shellenv --install --no-refresh-alias --omit-nix-env=true)"
  else
    eval "$("$devbox_bin" shellenv --install --no-refresh-alias --omit-nix-env=true)"
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    if [ -x /usr/bin/clang ]; then
      CC=/usr/bin/clang
      CXX=/usr/bin/clang++
      export CC CXX
    fi

    dev_dir="$(ios_resolve_developer_dir 2>/dev/null || true)"
    if [ -n "$dev_dir" ]; then
      DEVELOPER_DIR="$dev_dir"
      export DEVELOPER_DIR
      PATH="$DEVELOPER_DIR/usr/bin:$PATH"
    fi

    PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    export PATH
    unset SDKROOT
  fi

  if [ -n "$devbox_init_path" ]; then
    PATH="${devbox_init_path}:${PATH}"
  fi
  if [ -n "$devbox_project_bin" ]; then
    PATH="${devbox_project_bin}:${PATH}"
  fi
  if [ -n "$devbox_bin_dir" ]; then
    PATH="${devbox_bin_dir}:${PATH}"
  fi
  export PATH
}

devbox_omit_nix_env

if [ "$(uname -s)" = "Darwin" ]; then
  PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
  export PATH
  if [ -z "${DEVELOPER_DIR:-}" ]; then
    dev_dir="$(ios_resolve_developer_dir 2>/dev/null || true)"
    if [ -n "${dev_dir:-}" ] && [ -d "$dev_dir" ]; then
      DEVELOPER_DIR="$dev_dir"
      PATH="$DEVELOPER_DIR/usr/bin:$PATH"
      export DEVELOPER_DIR PATH
    fi
  fi
fi

if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  for script in ios.sh devices.sh; do
    if [ -f "${IOS_SCRIPTS_DIR%/}/$script" ]; then
      chmod +x "${IOS_SCRIPTS_DIR%/}/$script" 2>/dev/null || true
    fi
  done
  PATH="${IOS_SCRIPTS_DIR}:$PATH"
  export PATH
fi

ios_debug_log_script "templates/devbox/plugins/ios/scripts/env.sh"

if ios_debug_enabled; then
  ios_debug_dump_vars \
    IOS_DEVICES \
    IOS_DEFAULT_DEVICE \
    IOS_DEFAULT_RUNTIME \
    IOS_DEVELOPER_DIR \
    IOS_DOWNLOAD_RUNTIME \
    IOS_XCODE_ENV_PATH \
    DEVELOPER_DIR \
    SDKROOT \
    CC \
    CXX
fi

ios_show_summary() {
  ios_runtime="${IOS_DEFAULT_RUNTIME:-}"
  if [ -z "$ios_runtime" ] && command -v xcrun >/dev/null 2>&1; then
    ios_runtime="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
  fi

  xcode_dir="${DEVELOPER_DIR:-}"
  if [ -z "$xcode_dir" ] && command -v xcode-select >/dev/null 2>&1; then
    xcode_dir="$(xcode-select -p 2>/dev/null || true)"
  fi

  xcode_version="unknown"
  if command -v xcodebuild >/dev/null 2>&1; then
    xcode_version="$(xcodebuild -version 2>/dev/null | awk 'NR==1{print $2}')"
  fi

  ios_target_device="${IOS_DEFAULT_DEVICE:-}"
  ios_target_runtime="${ios_runtime:-}"

  echo "Resolved iOS SDK"
  echo "  DEVELOPER_DIR: ${xcode_dir:-not set}"
  echo "  XCODE_VERSION: ${xcode_version:-unknown}"
  echo "  IOS_RUNTIME: ${ios_runtime:-not set}"
  echo "  IOS_SIM_TARGET: device=${ios_target_device:-unknown} runtime=${ios_target_runtime:-not set}"
}

# Optionally print summary on init if INIT_IOS is set
if [ -n "${INIT_IOS:-}" ] && [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "${IOS_SDK_SUMMARY_PRINTED:-}" ]; then
  IOS_SDK_SUMMARY_PRINTED=1
  export IOS_SDK_SUMMARY_PRINTED
  ios_show_summary
fi

# Source all other iOS scripts to make functions available
# Each script has load-once guards to prevent duplicate sourcing
if [ -n "${IOS_SCRIPTS_DIR:-}" ]; then
  # lib.sh provides utility functions
  if [ -f "${IOS_SCRIPTS_DIR}/lib.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/lib.sh"
  fi

  # device.sh provides device query functions
  if [ -f "${IOS_SCRIPTS_DIR}/device.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/device.sh"
  fi

  # simulator.sh provides simulator lifecycle functions
  if [ -f "${IOS_SCRIPTS_DIR}/simulator.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/simulator.sh"
  fi

  # deploy.sh provides app deployment functions
  if [ -f "${IOS_SCRIPTS_DIR}/deploy.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/deploy.sh"
  fi

  # config.sh provides configuration management
  if [ -f "${IOS_SCRIPTS_DIR}/config.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/config.sh"
  fi
fi
