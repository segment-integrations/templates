#!/usr/bin/env sh
set -eu

if ! (return 0 2>/dev/null); then
  echo "devbox.d/android/scripts/avd.sh must be sourced." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${ANDROID_CONFIG_DIR:-}" ] && [ -d "${ANDROID_CONFIG_DIR}/scripts" ]; then
  script_dir="${ANDROID_CONFIG_DIR}/scripts"
fi

# shellcheck disable=SC1090
. "$script_dir/env.sh"
# shellcheck disable=SC1090
. "$script_dir/lib.sh"

android_debug_log_script "devbox.d/android/scripts/avd.sh"

resolve_java_home() {
  if [ -n "${ANDROID_JAVA_HOME:-}" ] && [ -x "$ANDROID_JAVA_HOME/bin/java" ]; then
    printf '%s\n' "$ANDROID_JAVA_HOME"
    return 0
  fi
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    printf '%s\n' "$JAVA_HOME"
    return 0
  fi
  java_bin="$(command -v java 2>/dev/null || true)"
  if [ -n "$java_bin" ]; then
    java_home="$(cd "$(dirname "$java_bin")/.." && pwd)"
    if [ -x "$java_home/bin/java" ]; then
      printf '%s\n' "$java_home"
      return 0
    fi
  fi
  return 1
}

run_avdmanager() {
  if [ -n "${ANDROID_JAVA_HOME:-}" ]; then
    JAVA_HOME="$ANDROID_JAVA_HOME" PATH="$ANDROID_JAVA_HOME/bin:$PATH" avdmanager "$@"
  else
    avdmanager "$@"
  fi
}

detect_sdk_root() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    printf '%s\n' "$ANDROID_SDK_ROOT"
    return 0
  fi
  return 1
}

avd_exists() {
  name="$1"
  run_avdmanager list avd | grep -q "Name: ${name}"
}

resolve_device() {
  desired="$1"
  if [ -z "$desired" ]; then
    return 1
  fi
  devices="$(run_avdmanager list device | awk -F': ' '
    /^id: /{
      id=$2
      if (index(id, "\"") > 0) {
        q=index(id, "\"")
        rest=substr(id, q + 1)
        q2=index(rest, "\"")
        if (q2 > 0) { id=substr(rest, 1, q2 - 1) }
      } else {
        split(id, parts, " ")
        id=parts[1]
      }
      next
    }
    /^[[:space:]]*Name: /{
      name=$2
      if (id != "") { print id "\t" name; id="" }
    }
  ')"
  if [ -z "$devices" ]; then
    return 1
  fi

  desired_norm="$(android_normalize_name "$desired")"
  desired_alt_norm="$(android_normalize_name "$(printf '%s' "$desired" | tr '_-' '  ')")"

  while IFS=$'\t' read -r id name; do
    id_norm="$(android_normalize_name "$id")"
    name_norm="$(android_normalize_name "$name")"
    if [ "$id_norm" = "$desired_norm" ] || [ "$id_norm" = "$desired_alt_norm" ] || \
      [ "$name_norm" = "$desired_norm" ] || [ "$name_norm" = "$desired_alt_norm" ]; then
      printf '%s\n' "$id"
      return 0
    fi
  done <<EOF
$devices
EOF

  return 1
}

pick_image() {
  api="$1"
  tag="$2"
  preferred_abi="$3"
  host_arch="$(uname -m)"

  if [ -n "$preferred_abi" ]; then
    candidates="$preferred_abi"
  else
    case "$host_arch" in
      arm64 | aarch64) candidates="arm64-v8a x86_64 x86" ;;
      *) candidates="x86_64 x86 arm64-v8a" ;;
    esac
  fi

  ifs_backup="$IFS"
  IFS=' '
  for abi in $candidates; do
    image="system-images;android-${api};${tag};${abi}"
    path="${ANDROID_SDK_ROOT}/system-images/android-${api}/${tag}/${abi}"
    if android_debug_enabled; then
      if [ -d "$path" ]; then
        echo "Debug: found ABI path $path" >&2
      else
        echo "Debug: missing ABI path $path" >&2
      fi
    fi
    if [ -d "$path" ]; then
      printf '%s\n' "$image"
      IFS="$ifs_backup"
      return 0
    fi
  done
  IFS="$ifs_backup"

  return 1
}

create_avd() {
  name="$1"
  device="$2"
  image="$3"
  abi="${image##*;}"

  if avd_exists "$name"; then
    echo "AVD ${name} already exists."
    return 0
  fi

  echo "Creating AVD ${name} with ${image}..."
  run_avdmanager create avd --force --name "$name" --package "$image" --device "$device" --abi "$abi" --sdcard 512M
}

add_target() {
  target_line="$1"
  if [ -z "${TARGETS:-}" ]; then
    TARGETS="$target_line"
  else
    TARGETS="${TARGETS}
${target_line}"
  fi
}

android_devices_dir() {
  if [ -n "${ANDROID_DEVICES_DIR:-}" ] && [ -d "$ANDROID_DEVICES_DIR" ]; then
    printf '%s\n' "$ANDROID_DEVICES_DIR"
    return 0
  fi
  if [ -n "${ANDROID_CONFIG_DIR:-}" ] && [ -d "${ANDROID_CONFIG_DIR}/devices" ]; then
    printf '%s\n' "${ANDROID_CONFIG_DIR}/devices"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -d "${DEVBOX_PROJECT_ROOT}/devbox.d/android/devices" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT}/devbox.d/android/devices"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -d "${DEVBOX_PROJECT_DIR}/devbox.d/android/devices" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR}/devbox.d/android/devices"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ] && [ -d "${DEVBOX_WD}/devbox.d/android/devices" ]; then
    printf '%s\n' "${DEVBOX_WD}/devbox.d/android/devices"
    return 0
  fi
  if [ -d "./devbox.d/android/devices" ]; then
    printf '%s\n' "./devbox.d/android/devices"
    return 0
  fi
  return 1
}

android_device_files() {
  dir="$1"
  if [ -z "$dir" ]; then
    return 1
  fi
  find "$dir" -type f -name '*.json' | sort
}

android_resolve_device_name() {
  selection="$1"
  devices_dir="$2"
  if [ -z "$selection" ] || [ -z "$devices_dir" ]; then
    return 1
  fi

  for device_file in $(android_device_files "$devices_dir"); do
    base="$(basename "$device_file")"
    base="${base%.json}"
    name="$(jq -r '.name // empty' "$device_file")"
    if [ "$selection" = "$base" ] || [ "$selection" = "$name" ]; then
      printf '%s\n' "$device_file"
      return 0
    fi
  done
  return 1
}

android_select_device_files() {
  devices_dir="$1"
  selection="${ANDROID_DEVICE_NAME:-${TARGET_DEVICE:-${ANDROID_DEFAULT_DEVICE:-}}}"
  if [ -n "$selection" ]; then
    match="$(android_resolve_device_name "$selection" "$devices_dir" || true)"
    if [ -n "$match" ]; then
      printf '%s\n' "$match"
      return 0
    fi
    echo "Warning: Android device '${selection}' not found in ${devices_dir}; using first definition." >&2
  fi
  android_device_files "$devices_dir"
}

android_setup() {
  TARGETS=""
  resolved_avd_name=""
  detected_sdk_root="$(detect_sdk_root 2>/dev/null || true)"

  if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -n "$detected_sdk_root" ]; then
    ANDROID_SDK_ROOT="$detected_sdk_root"
    export ANDROID_SDK_ROOT
  fi

  if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -z "${ANDROID_HOME:-}" ]; then
    echo "ANDROID_SDK_ROOT/ANDROID_HOME must be set. Ensure the Devbox Android SDK package is installed." >&2
    exit 1
  fi

  ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
  export ANDROID_HOME

  android_require_tool avdmanager
  android_require_tool emulator
  android_require_tool jq
  ANDROID_JAVA_HOME="${ANDROID_JAVA_HOME:-$(resolve_java_home 2>/dev/null || true)}"
  if [ -n "$ANDROID_JAVA_HOME" ]; then
    export ANDROID_JAVA_HOME
  fi

  devices_dir="$(android_devices_dir 2>/dev/null || true)"
  if [ -z "$devices_dir" ]; then
    echo "Android devices directory not found. Expected devbox.d/android/devices or ANDROID_DEVICES_DIR." >&2
    exit 1
  fi

  device_files="$(android_select_device_files "$devices_dir")"
  if [ -z "$device_files" ]; then
    echo "No Android device definitions found in ${devices_dir}." >&2
    exit 1
  fi

  for device_file in $device_files; do
    name="$(jq -r '.name // empty' "$device_file")"
    api="$(jq -r '.api // empty' "$device_file")"
    device="$(jq -r '.device // empty' "$device_file")"
    tag="$(jq -r '.tag // empty' "$device_file")"
    preferred_abi="$(jq -r '.preferred_abi // empty' "$device_file")"

    if [ -z "$api" ] || [ -z "$device" ]; then
      echo "Android device definition missing required fields in ${device_file} (api, device)." >&2
      exit 1
    fi
    if [ -z "$tag" ]; then
      tag="${ANDROID_SYSTEM_IMAGE_TAG:-google_apis}"
    fi

    resolved_device="$(resolve_device "$device" || true)"
    if [ -n "$resolved_device" ]; then
      device="$resolved_device"
    fi

    add_target "${api}|${tag}|${device}|${preferred_abi}|${name}"
  done

  if [ -z "$TARGETS" ]; then
    echo "No compatible Android system images found under ${ANDROID_SDK_ROOT}/system-images for configured APIs." >&2
    exit 1
  fi

  ifs_backup="$IFS"
  IFS="$(printf '\n')"
  for target in $TARGETS; do
    IFS='|' read -r api tag device preferred_abi name_override <<TARGET_EOF
$target
TARGET_EOF
    IFS="$(printf '\n')"
    api="${api-}"
    tag="${tag-}"
    device="${device-}"
    preferred_abi="${preferred_abi-}"
    name_override="${name_override-}"

    if android_debug_enabled; then
      api_image="$(pick_image "$api" "$tag" "$preferred_abi" || true)"
    else
      api_image="$(pick_image "$api" "$tag" "$preferred_abi" 2>/dev/null || true)"
    fi
    if [ -z "$api_image" ]; then
      if [ -n "$preferred_abi" ]; then
        android_require_dir_contains "$ANDROID_SDK_ROOT" "system-images/android-${api}/${tag}/${preferred_abi}" "Missing preferred ABI ${preferred_abi} for API ${api} (${tag}) under ${ANDROID_SDK_ROOT}."
      fi
      base_dir="${ANDROID_SDK_ROOT}/system-images/android-${api}/${tag}"
      if [ -d "$base_dir" ]; then
        available_abis="$(ls -1 "$base_dir" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
        if [ -n "$available_abis" ]; then
          host_arch="$(uname -m)"
          if [ -n "$preferred_abi" ]; then
            candidates="$preferred_abi"
          else
            case "$host_arch" in
              arm64 | aarch64) candidates="arm64-v8a x86_64 x86" ;;
              *) candidates="x86_64 x86 arm64-v8a" ;;
            esac
          fi
          echo "Debug: host_arch=${host_arch} candidates=${candidates} base_dir=${base_dir}" >&2
          echo "API ${api} system image tag '${tag}' found, but no compatible ABI (preferred ${preferred_abi:-auto}). Available: ${available_abis}." >&2
        else
          echo "API ${api} system image tag '${tag}' exists but has no ABI directories under ${base_dir}." >&2
        fi
      else
        echo "Expected API ${api} system image (${tag}; preferred ABI ${preferred_abi:-auto}) not found under ${ANDROID_SDK_ROOT}/system-images/android-${api}." >&2
      fi
      echo "Re-enter the devbox shell (flake should provide images) or rebuild Devbox to fetch them." >&2
      continue
    fi

    abi="${api_image##*;}"
    abi_safe="$(printf '%s' "$abi" | tr '-' '_')"
    if [ -n "$name_override" ]; then
      avd_name="$name_override"
    else
      safe_device="$(android_sanitize_avd_name "$device" || true)"
      if [ -z "$safe_device" ]; then
        echo "Unable to derive a valid AVD name from device '${device}'." >&2
        exit 1
      fi
      avd_name="$(printf '%s_API%s_%s' "$safe_device" "$api" "$abi_safe")"
    fi
  if [ -z "$resolved_avd_name" ]; then
    resolved_avd_name="$avd_name"
  fi

  create_avd "$avd_name" "$device" "$api_image"
    if avd_exists "$avd_name"; then
      echo "AVD ready: ${avd_name} (${api_image})"
    fi
  done
  IFS="$ifs_backup"

  if [ -n "$resolved_avd_name" ]; then
    ANDROID_RESOLVED_AVD="$resolved_avd_name"
    export ANDROID_RESOLVED_AVD
  fi
  echo "AVDs ready. Boot with: emulator -avd <name> --netdelay none --netspeed full"
}

android_start() {
  if [ -n "${1:-}" ]; then
    ANDROID_DEVICE_NAME="$1"
    export ANDROID_DEVICE_NAME
  fi
  headless="${EMU_HEADLESS:-}"
  port="${EMU_PORT:-5554}"
  avd=""

  android_setup

  if [ -z "$avd" ] && [ -n "${ANDROID_RESOLVED_AVD:-}" ]; then
    avd="$ANDROID_RESOLVED_AVD"
  fi

  if [ -z "$avd" ] && [ -n "${AVD_NAME:-}" ]; then
    avd="$AVD_NAME"
  fi

  if [ -z "$avd" ]; then
    echo "No AVD resolved; set ANDROID_DEVICE_NAME or AVD_NAME explicitly." >&2
    exit 1
  fi

  if command -v adb >/dev/null 2>&1; then
    adb devices | awk 'NR>1 && $2=="offline" {print $1}' | while read -r d; do adb -s "$d" emu kill >/dev/null 2>&1 || true; done

    for serial in $(adb devices | awk 'NR>1 && $1 ~ /^emulator-/{print $1}'); do
      running_name="$(adb -s "$serial" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d "\r")"
      if [ -n "$running_name" ] && [ "$running_name" = "$avd" ]; then
        ANDROID_EMULATOR_SERIAL="$serial"
        export ANDROID_EMULATOR_SERIAL
        EMU_PORT="${serial#emulator-}"
        export EMU_PORT
        echo "Android emulator already running: ${serial} (${running_name})"
        return 0
      fi
    done
  fi

  target_serial="emulator-${port}"
  if command -v adb >/dev/null 2>&1; then
    while adb devices | awk 'NR>1 && $1=="'"$target_serial"'"' | grep -q .; do
      port=$((port + 2))
      target_serial="emulator-${port}"
    done
  fi

  ANDROID_EMULATOR_SERIAL="$target_serial"
  export ANDROID_EMULATOR_SERIAL
  echo "Starting Android emulator: ${avd} (port ${port}, headless=${headless:-0})"
  if [ -n "$headless" ]; then
    headless_flag="-no-window"
  else
    headless_flag=""
  fi
  emulator -avd "$avd" ${headless_flag:+$headless_flag} -port "$port" -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none -accel on -writable-system -no-snapshot-save &
  EMULATOR_PID="$!"
  export EMULATOR_PID
  adb -s "$target_serial" wait-for-device
  boot_completed=""
  until [ "$boot_completed" = "1" ]; do
    boot_completed=$(adb -s "$target_serial" shell getprop sys.boot_completed 2>/dev/null | tr -d "\r")
    sleep 5
  done
  adb -s "$target_serial" shell settings put global window_animation_scale 0
  adb -s "$target_serial" shell settings put global transition_animation_scale 0
  adb -s "$target_serial" shell settings put global animator_duration_scale 0
}

android_service() {
  android_start "$1"

  trap 'android_stop; exit 0' INT TERM

  if [ -n "${EMULATOR_PID:-}" ]; then
    while kill -0 "$EMULATOR_PID" 2>/dev/null; do
      sleep 5
    done
  else
    while true; do
      sleep 5
    done
  fi
}

android_stop() {
  if command -v adb >/dev/null 2>&1; then
    adb devices | awk 'NR>1 && $2=="offline" {print $1}' | while read -r d; do adb -s "$d" emu kill >/dev/null 2>&1 || true; done
    devices="$(adb devices -l 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' ' ')"
    if [ -n "$devices" ]; then
      echo "Stopping Android emulators: $devices"
      for d in $devices; do
        adb -s "$d" emu kill >/dev/null 2>&1 || true
      done
    else
      echo "No Android emulators detected via adb."
    fi
  else
    echo "adb not found; skipping Android emulator shutdown."
  fi
  pkill -f "emulator@" >/dev/null 2>&1 || true
  echo "Android emulators stopped (if any were running)."
}

android_run_app() {
  device_choice="${1:-${TARGET_DEVICE:-}}"
  if [ -z "$device_choice" ] && [ -n "${ANDROID_DEFAULT_DEVICE:-}" ]; then
    device_choice="$ANDROID_DEFAULT_DEVICE"
  fi

  android_start "$device_choice"

  project_root="${DEVBOX_PROJECT_ROOT:-${DEVBOX_PROJECT_DIR:-${DEVBOX_WD:-$PWD}}}"
  if [ -z "$project_root" ] || [ ! -d "$project_root" ]; then
    echo "Unable to resolve project root for Android build." >&2
    exit 1
  fi

  app_id="${ANDROID_APP_ID:-}"
  if [ -z "$app_id" ]; then
    echo "ANDROID_APP_ID is required to start the app (e.g. com.example.app)." >&2
    exit 1
  fi

  apk_path="${ANDROID_APP_APK:-}"
  if [ -z "$apk_path" ]; then
    apk_path="$(find "$project_root" -path "*/build/outputs/apk/debug/*.apk" -type f | head -n1)"
  fi
  if [ -z "$apk_path" ] || [ ! -f "$apk_path" ]; then
    echo "Debug APK not found. Building with Gradle..." >&2
    (cd "$project_root" && gradle assembleDebug)
    apk_path="$(find "$project_root" -path "*/build/outputs/apk/debug/*.apk" -type f | head -n1)"
  fi
  if [ -z "$apk_path" ] || [ ! -f "$apk_path" ]; then
    echo "Unable to locate debug APK under ${project_root}." >&2
    exit 1
  fi

  target_serial="${ANDROID_EMULATOR_SERIAL:-emulator-${EMU_PORT:-5554}}"
  adb -s "$target_serial" wait-for-device
  adb -s "$target_serial" install -r "$apk_path" >/dev/null

  activity="${ANDROID_APP_ACTIVITY:-}"
  if [ -z "$activity" ]; then
    activity="$(adb -s "$target_serial" shell cmd package resolve-activity --brief "$app_id" 2>/dev/null | tr -d "\r" | tail -n1)"
  fi
  if [ -z "$activity" ]; then
    echo "Unable to resolve launch activity for ${app_id}." >&2
    return 1
  fi
  adb -s "$target_serial" shell am start -n "$activity" >/dev/null || true
}

android_reset() {
  rm_bin="rm"
  if [ "$(uname -s)" = "Darwin" ] && [ -x /bin/rm ]; then
    rm_bin="/bin/rm"
  fi
  sdk_home="${ANDROID_SDK_HOME:-}"
  if [ -z "$sdk_home" ]; then
    echo "ANDROID_SDK_HOME is not set; refusing to reset Android state outside the project." >&2
    return 1
  fi
  avd_dir="${ANDROID_AVD_HOME:-$sdk_home/avd}"
  android_dot_dir="$sdk_home/.android"

  resolve_path() {
    path="$1"
    if [ -d "$path" ]; then
      (cd "$path" 2>/dev/null && pwd)
      return $?
    fi
    if [ -e "$path" ]; then
      dir="$(cd "$(dirname "$path")" 2>/dev/null && pwd)" || return 1
      printf '%s/%s\n' "$dir" "$(basename "$path")"
      return 0
    fi
    return 1
  }

  safe_root="$(resolve_path "$sdk_home/.." 2>/dev/null || true)"
  if [ -z "$safe_root" ]; then
    echo "Unable to resolve Android devbox root; refusing to reset." >&2
    return 1
  fi

  is_safe_path() {
    target="$(resolve_path "$1" 2>/dev/null || true)"
    if [ -z "$target" ]; then
      return 1
    fi
    case "$target" in
      "$safe_root"/*) return 0 ;;
      *) return 1 ;;
    esac
  }

  safe_remove_dir() {
    target="$1"
    if [ -z "$target" ] || [ ! -e "$target" ]; then
      return 0
    fi
    if ! is_safe_path "$target"; then
      echo "Refusing to remove non-project Android path: $target" >&2
      return 1
    fi
    if command -v chflags >/dev/null 2>&1; then
      chflags -R nouchg "$target" >/dev/null 2>&1 || true
    fi
    chmod -R u+w "$target" >/dev/null 2>&1 || true
    if ! "$rm_bin" -rf "$target"; then
      echo "Failed to remove $target. Check permissions or Full Disk Access for your terminal." >&2
      return 1
    fi
  }

  safe_remove_file() {
    target="$1"
    if [ -z "$target" ] || [ ! -e "$target" ]; then
      return 0
    fi
    if ! is_safe_path "$target"; then
      echo "Refusing to remove non-project Android file: $target" >&2
      return 1
    fi
    if ! "$rm_bin" -f "$target"; then
      echo "Failed to remove $target. Check permissions." >&2
      return 1
    fi
  }

  safe_remove_dir "$avd_dir"
  safe_remove_dir "$android_dot_dir"
  safe_remove_file "$sdk_home/adbkey"
  safe_remove_file "$sdk_home/adbkey.pub"
  safe_remove_file "$android_dot_dir/adbkey"
  safe_remove_file "$android_dot_dir/adbkey.pub"

  echo "Project AVDs and adb keys removed. Recreate via start-android* as needed."
}
