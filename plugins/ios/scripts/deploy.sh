#!/usr/bin/env sh
# iOS Plugin - App Building and Deployment
# See REFERENCE.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: deploy.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_DEPLOY_LOADED:-}" = "1" ] && [ "${IOS_DEPLOY_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_DEPLOY_LOADED=1
IOS_DEPLOY_LOADED_PID="$$"

# Source dependencies
if [ -n "${IOS_SCRIPTS_DIR:-}" ]; then
  if [ -f "${IOS_SCRIPTS_DIR}/lib.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/lib.sh"
  fi
  if [ -f "${IOS_SCRIPTS_DIR}/core.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/core.sh"
  fi
  if [ -f "${IOS_SCRIPTS_DIR}/simulator.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/simulator.sh"
  fi
fi

ios_debug_log "deploy.sh loaded"

# ============================================================================
# Project and Path Resolution Functions
# ============================================================================

# Resolve Xcode project path
# Returns: project path
ios_resolve_app_project() {
  if [ -n "${IOS_APP_PROJECT:-}" ]; then
    printf '%s\n' "$IOS_APP_PROJECT"
    return 0
  fi
  for proj in *.xcodeproj; do
    [ -d "$proj" ] || continue
    printf '%s\n' "$proj"
    return 0
  done
  return 1
}

# Resolve Xcode scheme name
# Returns: scheme name
ios_resolve_app_scheme() {
  if [ -n "${IOS_APP_SCHEME:-}" ]; then
    printf '%s\n' "$IOS_APP_SCHEME"
    return 0
  fi
  project="$(ios_resolve_app_project 2>/dev/null || true)"
  if [ -n "$project" ]; then
    printf '%s\n' "$(basename "$project" .xcodeproj)"
    return 0
  fi
  return 1
}

# Resolve app bundle identifier
# Returns: bundle ID
ios_resolve_app_bundle_id() {
  if [ -n "${IOS_APP_BUNDLE_ID:-}" ]; then
    printf '%s\n' "$IOS_APP_BUNDLE_ID"
    return 0
  fi
  return 1
}

# Resolve derived data directory
# Returns: derived data path
ios_resolve_derived_data() {
  if [ -n "${IOS_APP_DERIVED_DATA:-}" ]; then
    printf '%s\n' "$IOS_APP_DERIVED_DATA"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT%/}/.devbox/virtenv/ios/DerivedData"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR%/}/.devbox/virtenv/ios/DerivedData"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ]; then
    printf '%s\n' "${DEVBOX_WD%/}/.devbox/virtenv/ios/DerivedData"
    return 0
  fi
  printf '%s\n' "./.devbox/virtenv/ios/DerivedData"
}

# Resolve project root directory
# Returns: project root path
ios_resolve_project_root() {
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT%/}"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR%/}"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ]; then
    printf '%s\n' "${DEVBOX_WD%/}"
    return 0
  fi
  printf '%s\n' "$PWD"
}

# Resolve devbox binary path
# Returns: devbox binary path
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

# ============================================================================
# Build Functions
# ============================================================================

# Run iOS build using devbox
# Returns: 0 on success
ios_run_build() {
  project_root="$(ios_resolve_project_root)"
  if [ -z "$project_root" ] || [ ! -d "$project_root" ]; then
    echo "Unable to resolve project root for iOS build." >&2
    return 1
  fi
  devbox_bin="$(ios_resolve_devbox_bin 2>/dev/null || true)"
  if [ -z "$devbox_bin" ]; then
    echo "devbox is required to run the project build." >&2
    return 1
  fi
  (cd "$project_root" && "$devbox_bin" run --pure build-ios)
}

# Resolve app bundle path using glob pattern
# Returns: app bundle path
ios_resolve_app_path() {
  project_root="$(ios_resolve_project_root)"
  pattern="${IOS_APP_ARTIFACT:-}"
  if [ -z "$pattern" ]; then
    return 1
  fi
  if [ "${pattern#/}" = "$pattern" ]; then
    pattern="${project_root%/}/$pattern"
  fi
  set +f
  matches=""
  for candidate in $pattern; do
    if [ -d "$candidate" ]; then
      matches="${matches}${matches:+
}$candidate"
    fi
  done
  set -f
  if [ -z "$matches" ]; then
    return 1
  fi
  count="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
  if [ "$count" -gt 1 ]; then
    echo "Multiple app bundles matched ${pattern}; using the first match." >&2
  fi
  printf '%s\n' "$matches" | head -n1
}

# ============================================================================
# Setup Orchestration
# ============================================================================

# Setup iOS environment for deployment
# Returns: 0 on success
ios_setup() {
  if [ -n "${IOS_XCODE_ENV_PATH:-}" ]; then
    node_binary="${IOS_NODE_BINARY:-${NODE_BINARY:-}}"
    if [ -z "$node_binary" ]; then
      echo "IOS_XCODE_ENV_PATH is set but IOS_NODE_BINARY/NODE_BINARY is empty." >&2
      return 1
    fi
    env_dir="$(dirname "$IOS_XCODE_ENV_PATH")"
    if [ ! -d "$env_dir" ]; then
      echo "IOS_XCODE_ENV_PATH directory does not exist: ${env_dir}" >&2
      return 1
    fi
    printf 'export NODE_BINARY=%s\n' "$node_binary" >"$IOS_XCODE_ENV_PATH"
  fi
  ensure_developer_dir
  ios_require_tool xcrun "Missing required tool: xcrun. Install Xcode CLI tools before running (xcode-select --install or Xcode.app + xcode-select -s)."
  ios_require_tool jq
  ensure_simctl

  if ! ensure_core_sim_service; then
    return 1
  fi

  devices_dir="$(ios_devices_dir 2>/dev/null || true)"
  if [ -z "$devices_dir" ]; then
    echo "iOS devices directory not found. Expected devbox.d/ios/devices or IOS_DEVICES_DIR." >&2
    return 1
  fi

  device_files="$(ios_device_files "$devices_dir")"
  if [ -z "$device_files" ]; then
    echo "No iOS device definitions found in ${devices_dir}." >&2
    return 1
  fi

  device_files="$(ios_selected_device_files "$devices_dir")" || return 1
  for device_file in $device_files; do
    device_name="$(jq -r '.name // empty' "$device_file")"
    runtime="$(jq -r '.runtime // empty' "$device_file")"
    if [ -z "$device_name" ]; then
      echo "iOS device definition missing name in ${device_file}." >&2
      return 1
    fi
    if [ -z "$runtime" ]; then
      runtime="${IOS_DEFAULT_RUNTIME:-}"
      if [ -z "$runtime" ] && command -v xcrun >/dev/null 2>&1; then
        runtime="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
      fi
    fi
    if [ -z "$runtime" ]; then
      echo "IOS_DEFAULT_RUNTIME must be set (or install a simulator runtime in Xcode)." >&2
      return 1
    fi
    ensure_device "$device_name" "$runtime"
  done

  echo "Done. Launch via Xcode > Devices or 'xcrun simctl boot \"<name>\"' then 'open -a Simulator'."
}

# ============================================================================
# App Deployment
# ============================================================================

# Build, install, and launch app on simulator
# Args: device_name (optional)
# Returns: 0 on success
ios_run_app() {
  device_name="${1-}"
  ios_start "$device_name"

  ios_run_build

  app_path="$(ios_resolve_app_path || true)"
  if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
    echo "Unable to locate app bundle using IOS_APP_ARTIFACT=${IOS_APP_ARTIFACT:-}." >&2
    return 1
  fi
  bundle_id="$(ios_resolve_app_bundle_id || true)"
  if [ -z "$bundle_id" ]; then
    plist="${app_path%/}/Info.plist"
    if [ -f "$plist" ]; then
      bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)"
    fi
  fi
  if [ -z "$bundle_id" ]; then
    echo "Unable to resolve bundle identifier for ${app_path}." >&2
    return 1
  fi
  udid="${IOS_SIM_UDID:-}"
  if [ -z "$udid" ]; then
    echo "iOS simulator UDID not available; ensure the simulator is booted." >&2
    return 1
  fi

  xcrun simctl install "$udid" "$app_path"
  xcrun simctl launch "$udid" "$bundle_id"
}
