#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
Usage: devices.sh <command> [args]
       DEVICES_CMD="list" devices.sh

Commands:
  list
  show <name>
  create <name> --api <n> --device <id> [--tag <tag>] [--abi <abi>]
  update <name> [--name <new>] [--api <n>] [--device <id>] [--tag <tag>] [--abi <abi>]
  delete <name>
  select <name...>
  reset
  eval

Tag values: default google_apis google_apis_playstore play_store aosp_atd google_atd
ABI values: arm64-v8a x86_64 x86
USAGE
  exit 1
}

if [ -z "${1-}" ] && [ -n "${DEVICES_CMD:-}" ]; then
  set -- $DEVICES_CMD
fi

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
config_path="${config_dir%/}/android.json"
devices_dir="${ANDROID_DEVICES_DIR:-${config_dir%/}/devices}"
scripts_dir="${ANDROID_SCRIPTS_DIR:-${config_dir%/}/scripts}"
lock_path="${config_dir%/}/devices.lock.json"
allowed_tags="default google_apis google_apis_playstore play_store aosp_atd google_atd"
allowed_abis="arm64-v8a x86_64 x86"

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    exit 1
  fi
}

resolve_device_file() {
  selection="$1"
  if [ -z "$selection" ]; then
    return 1
  fi
  if [ -f "$devices_dir/${selection}.json" ]; then
    printf '%s\n' "$devices_dir/${selection}.json"
    return 0
  fi
  for file in "$devices_dir"/*.json; do
    [ -f "$file" ] || continue
    name="$(jq -r '.name // empty' "$file")"
    if [ "$name" = "$selection" ]; then
      printf '%s\n' "$file"
      return 0
    fi
  done
  return 1
}

require_jq

validate_api() {
  value="$1"
  case "$value" in
    ''|*[!0-9]*)
      echo "Invalid api: $value" >&2
      exit 1
      ;;
  esac
}

validate_tag() {
  value="$1"
  for tag in $allowed_tags; do
    if [ "$tag" = "$value" ]; then
      return 0
    fi
  done
  echo "Invalid tag: $value" >&2
  exit 1
}

validate_abi() {
  value="$1"
  for abi in $allowed_abis; do
    if [ "$abi" = "$value" ]; then
      return 0
    fi
  done
  echo "Invalid abi: $value" >&2
  exit 1
}

case "$command_name" in
  list)
    for file in "$devices_dir"/*.json; do
      [ -f "$file" ] || continue
      jq -r '"\(.name // "")\t\(.api // "")\t\(.device // "")\t\(.tag // "")\t\(.preferred_abi // "")\t\(. | @json)"' "$file"
    done
    ;;
  show)
    name="${1-}"
    [ -n "$name" ] || usage
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    cat "$file"
    ;;
  create)
    name="${1-}"
    [ -n "$name" ] || usage
    shift || true
    api=""
    device=""
    tag=""
    abi=""
    while [ "${1-}" != "" ]; do
      case "$1" in
        --api) api="$2"; shift 2 ;;
        --device) device="$2"; shift 2 ;;
        --tag) tag="$2"; shift 2 ;;
        --abi) abi="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [ -n "$api" ] || { echo "--api is required" >&2; exit 1; }
    [ -n "$device" ] || { echo "--device is required" >&2; exit 1; }
    validate_api "$api"
    if [ -n "$tag" ]; then
      validate_tag "$tag"
    fi
    if [ -n "$abi" ]; then
      validate_abi "$abi"
    fi
    mkdir -p "$devices_dir"
    jq -n --arg name "$name" --argjson api "$api" --arg device "$device" --arg tag "$tag" --arg abi "$abi" '
      {name:$name, api:$api, device:$device}
      + (if $tag != "" then {tag:$tag} else {} end)
      + (if $abi != "" then {preferred_abi:$abi} else {} end)
    ' >"$devices_dir/${name}.json"
    ;;
  update)
    name="${1-}"
    [ -n "$name" ] || usage
    shift || true
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    new_name=""
    api=""
    device=""
    tag=""
    abi=""
    while [ "${1-}" != "" ]; do
      case "$1" in
        --name) new_name="$2"; shift 2 ;;
        --api) api="$2"; shift 2 ;;
        --device) device="$2"; shift 2 ;;
        --tag) tag="$2"; shift 2 ;;
        --abi) abi="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    if [ -n "$api" ]; then
      validate_api "$api"
    fi
    if [ -n "$tag" ]; then
      validate_tag "$tag"
    fi
    if [ -n "$abi" ]; then
      validate_abi "$abi"
    fi
    tmp="${file}.tmp"
    jq \
      --arg name "$new_name" \
      --arg api "$api" \
      --arg device "$device" \
      --arg tag "$tag" \
      --arg abi "$abi" \
      '(
        if $name != "" then .name=$name else . end
      ) | (
        if $api != "" then .api=($api|tonumber) else . end
      ) | (
        if $device != "" then .device=$device else . end
      ) | (
        if $tag != "" then .tag=$tag else . end
      ) | (
        if $abi != "" then .preferred_abi=$abi else . end
      )' "$file" >"$tmp"
    mv "$tmp" "$file"
    if [ -n "$new_name" ]; then
      mv "$file" "$devices_dir/${new_name}.json"
    fi
    ;;
  delete)
    name="${1-}"
    [ -n "$name" ] || usage
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    rm -f "$file"
    ;;
  select)
    [ "${1-}" != "" ] || usage
    "${scripts_dir%/}/select-device.sh" "$@"
    "$0" eval >/dev/null
    ;;
  reset)
    tmp="${config_path}.tmp"
    jq '.EVALUATE_DEVICES = []' "$config_path" >"$tmp"
    mv "$tmp" "$config_path"
    echo "Selected Android devices: all"
    "$0" eval >/dev/null
    ;;
  eval)
    if [ ! -d "$devices_dir" ]; then
      echo "Devices directory not found: $devices_dir" >&2
      exit 1
    fi
    files="$(ls "$devices_dir"/*.json 2>/dev/null || true)"
    if [ -z "$files" ]; then
      echo "No device definitions found in ${devices_dir}." >&2
      exit 1
    fi

    devices_json="$(
      for file in $files; do
        jq -c --arg path "$file" '{file:$path, name:(.name // ""), api:(.api // null)}' "$file"
      done | jq -s '.'
    )"
    selected_list="$(jq -r '.EVALUATE_DEVICES[]?' "$config_path")"
    extra_platforms="$(jq -r '.ANDROID_PLATFORM_VERSIONS[]?' "$config_path")"

    api_values=""
    if [ -n "$selected_list" ]; then
      while read -r sel; do
        [ -n "$sel" ] || continue
        match="$(printf '%s\n' "$devices_json" | jq -r --arg sel "$sel" '
          .[] | select((.file | sub("^.*/"; "") | sub("\\.json$"; "")) == $sel or .name == $sel) | .file' | head -n1)"
        if [ -z "$match" ]; then
          echo "EVALUATE_DEVICES '${sel}' not found in devbox.d/android/devices." >&2
          exit 1
        fi
        api="$(printf '%s\n' "$devices_json" | jq -r --arg file "$match" '.[] | select(.file == $file) | .api' | head -n1)"
        if [ -n "$api" ] && [ "$api" != "null" ]; then
          api_values="${api_values}${api_values:+
}${api}"
        fi
      done <<EOF
$selected_list
EOF
    else
      api_values="$(printf '%s\n' "$devices_json" | jq -r '.[] | .api' | awk 'NF')"
    fi

    if [ -n "$extra_platforms" ]; then
      while read -r extra; do
        [ -n "$extra" ] || continue
        api_values="${api_values}${api_values:+
}${extra}"
      done <<EOF
$extra_platforms
EOF
    fi

    if [ -z "$api_values" ]; then
      echo "No device APIs found in ${devices_dir}." >&2
      exit 1
    fi
    temp_lock="${lock_path}.tmp"
    printf '%s\n' "$api_values" | awk 'NF' | sort -u | jq -R -s '{api_versions: (split("\n") | map(select(length>0)) | map(tonumber))}' >"$temp_lock"
    mv "$temp_lock" "$lock_path"
    jq -r '.api_versions | join(",")' "$lock_path"
    ;;
  *)
    usage
    ;;
esac
