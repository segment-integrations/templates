#!/usr/bin/env sh
set -eu

if ! (return 0 2>/dev/null); then
  echo "templates/devbox/plugins/ios/scripts/simctl.sh must be sourced." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/env.sh"

ios_debug_log_script "templates/devbox/plugins/ios/scripts/simctl.sh"

ios_config_path() {
  if [ -n "${IOS_CONFIG_DIR:-}" ] && [ -f "${IOS_CONFIG_DIR%/}/ios.json" ]; then
    printf '%s\n' "${IOS_CONFIG_DIR%/}/ios.json"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -f "${DEVBOX_PROJECT_ROOT}/devbox.d/ios/ios.json" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT}/devbox.d/ios/ios.json"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -f "${DEVBOX_PROJECT_DIR}/devbox.d/ios/ios.json" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR}/devbox.d/ios/ios.json"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ] && [ -f "${DEVBOX_WD}/devbox.d/ios/ios.json" ]; then
    printf '%s\n' "${DEVBOX_WD}/devbox.d/ios/ios.json"
    return 0
  fi
  if [ -f "./devbox.d/ios/ios.json" ]; then
    printf '%s\n' "./devbox.d/ios/ios.json"
    return 0
  fi
  return 1
}

ensure_core_sim_service() {
  status=0
  output="$(xcrun simctl list devices -j 2>&1)" || status=$?
  if [ "$status" -ne 0 ]; then
    echo "simctl failed while listing devices (status ${status}). CoreSimulatorService may be unhealthy." >&2
    echo "Try restarting it:" >&2
    echo "  killall -9 com.apple.CoreSimulatorService 2>/dev/null || true" >&2
    echo "  launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService" >&2
    echo "Then open Simulator once and rerun devbox run setup-ios." >&2
    echo "simctl error output:" >&2
    echo "$output" >&2
    return 1
  fi

  if echo "$output" | grep -q "CoreSimulatorService connection became invalid"; then
    echo "CoreSimulatorService is not healthy. Try restarting it:" >&2
    echo "  killall -9 com.apple.CoreSimulatorService 2>/dev/null || true" >&2
    echo "  launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService" >&2
    echo "Then open Simulator once and rerun devbox run setup-ios." >&2
    echo "simctl error output:" >&2
    echo "$output" >&2
    return 1
  fi
}

pick_runtime() {
  preferred="$1"
  json="$(xcrun simctl list runtimes -j)"
  choice="$(echo "$json" | jq -r --arg v "$preferred" '.runtimes[] | select(.isAvailable and (.name|startswith("iOS \($v)"))) | "\(.identifier)|\(.name)"' | head -n1)"
  if [ -z "$choice" ] || [ "$choice" = "null" ]; then
    choice="$(echo "$json" | jq -r '.runtimes[] | select(.isAvailable and (.name|startswith("iOS "))) | "\(.version)|\(.identifier)|\(.name)"' | sort -Vr | head -n1 | cut -d"|" -f2-)"
  fi
  if [ -n "$choice" ] && [ "$choice" != "null" ]; then
    printf '%s\n' "$choice"
    return 0
  fi
  return 1
}

resolve_runtime() {
  preferred="$1"
  if choice="$(pick_runtime "$preferred")"; then
    printf '%s\n' "$choice"
    return 0
  fi

  if [ "${IOS_DOWNLOAD_RUNTIME:-1}" != "0" ] && command -v xcodebuild >/dev/null 2>&1; then
    echo "Preferred runtime iOS ${preferred} not found. Attempting to download via xcodebuild -downloadPlatform iOS..." >&2
    if xcodebuild -downloadPlatform iOS; then
      if choice="$(pick_runtime "$preferred")"; then
        printf '%s\n' "$choice"
        return 0
      fi
    else
      echo "xcodebuild -downloadPlatform iOS failed; continuing with available runtimes." >&2
    fi
  fi

  pick_runtime "$preferred"
}

resolve_runtime_strict() {
  preferred="$1"
  if choice="$(pick_runtime "$preferred")"; then
    printf '%s\n' "$choice"
    return 0
  fi

  if [ "${IOS_DOWNLOAD_RUNTIME:-1}" != "0" ] && command -v xcodebuild >/dev/null 2>&1; then
    echo "Preferred runtime iOS ${preferred} not found. Attempting to download via xcodebuild -downloadPlatform iOS..." >&2
    if xcodebuild -downloadPlatform iOS; then
      if choice="$(pick_runtime "$preferred")"; then
        printf '%s\n' "$choice"
        return 0
      fi
    else
      echo "xcodebuild -downloadPlatform iOS failed." >&2
    fi
  fi

  echo "Preferred runtime iOS ${preferred} not found." >&2
  return 1
}

resolve_runtime_name() {
  preferred="$1"
  choice="$(resolve_runtime "$preferred" || true)"
  if [ -n "$choice" ]; then
    printf '%s\n' "$choice" | cut -d'|' -f2
    return 0
  fi
  return 1
}

resolve_runtime_name_strict() {
  preferred="$1"
  choice="$(resolve_runtime_strict "$preferred" || true)"
  if [ -n "$choice" ]; then
    printf '%s\n' "$choice" | cut -d'|' -f2
    return 0
  fi
  return 1
}

ios_devices_dir() {
  if [ -n "${IOS_DEVICES_DIR:-}" ] && [ -d "$IOS_DEVICES_DIR" ]; then
    printf '%s\n' "$IOS_DEVICES_DIR"
    return 0
  fi
  if [ -n "${IOS_CONFIG_DIR:-}" ] && [ -d "${IOS_CONFIG_DIR}/devices" ]; then
    printf '%s\n' "${IOS_CONFIG_DIR}/devices"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -d "${DEVBOX_PROJECT_ROOT}/devbox.d/ios/devices" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT}/devbox.d/ios/devices"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -d "${DEVBOX_PROJECT_DIR}/devbox.d/ios/devices" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR}/devbox.d/ios/devices"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ] && [ -d "${DEVBOX_WD}/devbox.d/ios/devices" ]; then
    printf '%s\n' "${DEVBOX_WD}/devbox.d/ios/devices"
    return 0
  fi
  if [ -d "./devbox.d/ios/devices" ]; then
    printf '%s\n' "./devbox.d/ios/devices"
    return 0
  fi
  return 1
}

ios_device_files() {
  dir="$1"
  if [ -z "$dir" ]; then
    return 1
  fi
  find "$dir" -type f -name '*.json' | sort
}

ios_selected_device_files() {
  devices_dir="$1"
  config_path="$(ios_config_path 2>/dev/null || true)"
  if [ -z "$config_path" ] || [ ! -f "$config_path" ]; then
    ios_device_files "$devices_dir"
    return 0
  fi
  selections="$(jq -r '.EVALUATE_DEVICES // [] | if length == 0 then empty else .[] end' "$config_path")"
  if [ -z "$selections" ]; then
    ios_device_files "$devices_dir"
    return 0
  fi

  matched=""
  for file in $(ios_device_files "$devices_dir"); do
    base="$(basename "$file")"
    base="${base%.json}"
    name="$(jq -r '.name // empty' "$file")"
    for selection in $selections; do
      if [ "$selection" = "$base" ] || [ "$selection" = "$name" ]; then
        matched="${matched}${file}
"
        break
      fi
    done
  done
  if [ -z "$matched" ]; then
    echo "No iOS device definitions matched EVALUATE_DEVICES in ${config_path}." >&2
    return 1
  fi
  printf '%s' "$matched"
}

ios_device_runtime_for_name() {
  name="$1"
  dir="$(ios_devices_dir 2>/dev/null || true)"
  if [ -z "$dir" ]; then
    return 1
  fi
  for file in $(ios_device_files "$dir"); do
    file_name="$(jq -r '.name // empty' "$file")"
    if [ -n "$file_name" ] && [ "$file_name" = "$name" ]; then
      runtime="$(jq -r '.runtime // empty' "$file")"
      if [ -n "$runtime" ]; then
        printf '%s\n' "$runtime"
        return 0
      fi
    fi
  done
  return 1
}

ios_select_device_name() {
  selection="$1"
  dir="$2"
  if [ -z "$dir" ]; then
    return 1
  fi
  if [ -n "$selection" ]; then
    for file in $(ios_device_files "$dir"); do
      base="$(basename "$file")"
      base="${base%.json}"
      name="$(jq -r '.name // empty' "$file")"
      if [ "$selection" = "$base" ] || [ "$selection" = "$name" ]; then
        printf '%s\n' "$name"
        return 0
      fi
    done
    echo "Warning: iOS device '${selection}' not found in ${dir}; using first definition." >&2
  fi
  first_file="$(ios_device_files "$dir" | head -n1)"
  if [ -n "$first_file" ]; then
    first_name="$(jq -r '.name // empty' "$first_file")"
    if [ -n "$first_name" ]; then
      printf '%s\n' "$first_name"
      return 0
    fi
  fi
  return 1
}

existing_device_udid_any_runtime() {
  name="$1"
  xcrun simctl list devices -j | jq -r --arg name "$name" '.devices[]?[]? | select(.name == $name) | .udid' | head -n1
}

device_data_dir_exists() {
  udid="${1:-}"
  if [ -z "$udid" ]; then
    return 1
  fi
  dir="$HOME/Library/Developer/CoreSimulator/Devices/$udid"
  [ -d "$dir" ]
}

devicetype_id_for_name() {
  name="$1"
  xcrun simctl list devicetypes -j | jq -r --arg name "$name" '.devicetypes[] | select((.name|ascii_downcase) == ($name|ascii_downcase)) | .identifier' | head -n1
}

ensure_device() {
  base_name="$1"
  preferred_runtime="$2"

  existing_udid="$(existing_device_udid_any_runtime "$base_name")"
  if [ -n "$existing_udid" ]; then
    if device_data_dir_exists "$existing_udid"; then
      echo "Found existing ${base_name}: ${existing_udid}"
      return 0
    fi
    echo "Existing ${base_name} (${existing_udid}) is missing its data directory. Deleting stale simulator..."
    xcrun simctl delete "$existing_udid" || true
  fi

  choice="$(resolve_runtime "$preferred_runtime" || true)"
  if [ -z "$choice" ]; then
    echo "No available iOS simulator runtime found. Install one in Xcode (Settings > Platforms) and retry." >&2
    return 1
  fi
  runtime_id="$(printf '%s' "$choice" | cut -d'|' -f1)"
  runtime_name="$(printf '%s' "$choice" | cut -d'|' -f2)"

  display_name="${base_name} (${runtime_name})"

  device_type="$(devicetype_id_for_name "$base_name" || true)"
  if [ -z "$device_type" ]; then
    echo "Device type '${base_name}' is unavailable in this Xcode install. Skipping ${display_name}." >&2
    return 0
  fi

  existing_udid="$(existing_device_udid_any_runtime "$display_name")"
  if [ -n "$existing_udid" ]; then
    if device_data_dir_exists "$existing_udid"; then
      echo "Found existing ${display_name}: ${existing_udid}"
      return 0
    fi
    echo "Existing ${display_name} (${existing_udid}) is missing its data directory. Deleting stale simulator..."
    xcrun simctl delete "$existing_udid" || true
  fi

  echo "Creating ${display_name}..."
  xcrun simctl create "$display_name" "$device_type" "$runtime_id"
  echo "Created ${display_name}"
}

ensure_developer_dir() {
  desired="${IOS_DEVELOPER_DIR:-}"
  PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
  export PATH
  if [ -z "$desired" ]; then
    desired="$(ios_resolve_developer_dir 2>/dev/null || true)"
  fi

  ios_require_dir "$desired" "Xcode developer directory not found. Install Xcode/CLI tools or set IOS_DEVELOPER_DIR to an Xcode path (e.g., /Applications/Xcode.app/Contents/Developer)."
  ios_require_dir_contains "$desired" "Toolchains/XcodeDefault.xctoolchain" "Xcode toolchain missing under ${desired}."
  ios_require_dir_contains "$desired" "Platforms/iPhoneSimulator.platform" "iPhoneSimulator platform missing under ${desired}."

  DEVELOPER_DIR="$desired"
  PATH="$DEVELOPER_DIR/usr/bin:$PATH"
  export DEVELOPER_DIR PATH
  return 0
}

ensure_simctl() {
  if xcrun -f simctl >/dev/null 2>&1; then
    return 0
  fi
  cat >&2 <<'EOM'
Missing simctl.
- The standalone Command Line Tools do NOT include simctl; you need full Xcode.
- Install/locate Xcode.app, then select it:
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
- You can also set IOS_DEVELOPER_DIR to your Xcode path for this script.
EOM
  exit 1
}

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

resolve_service_device_name() {
  if [ -n "${IOS_SIM_DEVICE:-}" ]; then
    printf '%s\n' "$IOS_SIM_DEVICE"
    return 0
  fi
  if [ -n "${IOS_DEVICE_NAME:-}" ]; then
    printf '%s\n' "$IOS_DEVICE_NAME"
    return 0
  fi
  devices_dir="$(ios_devices_dir 2>/dev/null || true)"
  if [ -n "$devices_dir" ]; then
    selection="${IOS_DEFAULT_DEVICE:-}"
    ios_select_device_name "$selection" "$devices_dir" && return 0
  fi
  return 1
}

ios_start() {
  if [ -n "${1:-}" ]; then
    IOS_DEVICE_NAME="$1"
    export IOS_DEVICE_NAME
  fi
  headless="${SIM_HEADLESS:-}"

  ensure_developer_dir
  ios_require_tool jq
  ensure_simctl
  if ! ensure_core_sim_service; then
    return 1
  fi

  device_base="$(resolve_service_device_name || true)"
  if [ -z "$device_base" ]; then
    echo "No iOS simulator device configured; set IOS_DEVICE_NAME or IOS_DEFAULT_DEVICE." >&2
    return 1
  fi

  preferred_runtime="$(ios_device_runtime_for_name "$device_base" || true)"
  if [ -z "$preferred_runtime" ]; then
    preferred_runtime="${IOS_DEFAULT_RUNTIME:-}"
    if [ -z "$preferred_runtime" ] && command -v xcrun >/dev/null 2>&1; then
      preferred_runtime="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
    fi
  fi
  choice="$(resolve_runtime "$preferred_runtime" || true)"
  if [ -z "$choice" ]; then
    echo "No available iOS simulator runtime found. Install one in Xcode (Settings > Platforms) and retry." >&2
    return 1
  fi
  runtime_name="$(printf '%s' "$choice" | cut -d'|' -f2)"

  ensure_device "$device_base" "$preferred_runtime"
  display_name="${device_base} (${runtime_name})"
  udid="$(xcrun simctl list devices -j | jq -r --arg name "$display_name" '.devices[]?[]? | select(.name == $name) | .udid' | head -n1)"
  if [ -z "$udid" ]; then
    udid="$(existing_device_udid_any_runtime "$device_base" || true)"
  fi
  if [ -z "$udid" ]; then
    echo "Unable to resolve iOS simulator device for ${display_name}." >&2
    return 1
  fi

  IOS_SIM_UDID="$udid"
  IOS_SIM_NAME="$display_name"
  export IOS_SIM_UDID IOS_SIM_NAME

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  if ! xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1; then
    while true; do
      state="$(xcrun simctl list devices -j | jq -r --arg udid "$udid" '.devices[]?[]? | select(.udid == $udid) | .state' | head -n1)"
      [ "$state" = "Booted" ] && break
      sleep 5
    done
  fi

  if [ -z "$headless" ]; then
    open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
  fi
  echo "iOS simulator booted: ${display_name} (${udid}, headless=${headless:-0})"
}

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

ios_resolve_app_bundle_id() {
  if [ -n "${IOS_APP_BUNDLE_ID:-}" ]; then
    printf '%s\n' "$IOS_APP_BUNDLE_ID"
    return 0
  fi
  return 1
}

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

ios_build_app() {
  ios_require_tool xcodebuild
  project="$(ios_resolve_app_project || true)"
  scheme="$(ios_resolve_app_scheme || true)"
  if [ -z "$project" ] || [ -z "$scheme" ]; then
    echo "Unable to resolve iOS project/scheme. Set IOS_APP_PROJECT and IOS_APP_SCHEME." >&2
    return 1
  fi
  derived_data="$(ios_resolve_derived_data)"
  mkdir -p "$derived_data"
  env -u LD -u LDFLAGS -u NIX_LDFLAGS -u NIX_CFLAGS_COMPILE -u NIX_CFLAGS_LINK \
    xcodebuild -project "$project" -scheme "$scheme" -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" build
}

ios_app_path() {
  scheme="$(ios_resolve_app_scheme || true)"
  derived_data="$(ios_resolve_derived_data)"
  if [ -z "$scheme" ]; then
    return 1
  fi
  printf '%s\n' "${derived_data%/}/Build/Products/Debug-iphonesimulator/${scheme}.app"
}

ios_run_app() {
  device_name="${1-}"
  ios_start "$device_name"

  ios_build_app

  app_path="$(ios_app_path || true)"
  bundle_id="$(ios_resolve_app_bundle_id || true)"
  if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
    echo "Built app not found at ${app_path}." >&2
    return 1
  fi
  if [ -z "$bundle_id" ]; then
    echo "IOS_APP_BUNDLE_ID is required to launch the app." >&2
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

ios_stop() {
  udid="${IOS_SIM_UDID:-}"
  if [ -z "$udid" ] && [ -n "${IOS_SIM_NAME:-}" ]; then
    udid="$(xcrun simctl list devices -j | jq -r --arg name "$IOS_SIM_NAME" '.devices[]?[]? | select(.name == $name) | .udid' | head -n1)"
  fi
  if [ -n "$udid" ]; then
    echo "Stopping iOS simulator: ${udid}"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  else
    echo "Stopping booted iOS simulators (if any)."
    xcrun simctl shutdown booted >/dev/null 2>&1 || true
  fi
}

ios_service() {
  ios_start "${1-}"

  trap 'ios_stop; exit 0' INT TERM

  udid="${IOS_SIM_UDID:-}"
  if [ -z "$udid" ]; then
    while true; do
      sleep 5
    done
  fi

  while true; do
    state="$(xcrun simctl list devices -j | jq -r --arg udid "$udid" '.devices[]?[]? | select(.udid == $udid) | .state' | head -n1)"
    [ -z "$state" ] && break
    [ "$state" = "Shutdown" ] && break
    sleep 5
  done
}
