#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
Usage: ios.sh <command> [args]

Commands:
  devices <command> [args]
  config show
  config set key=value [key=value...]
  config reset
  info

Examples:
  ios.sh devices list
  ios.sh devices create iphone15 --runtime 17.5
  ios.sh config set IOS_DEFAULT_DEVICE=max
USAGE
  exit 1
}

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

case "$command_name" in
  devices)
    exec "${script_dir}/devices.sh" "$@"
    ;;
  config)
    sub="${1-}"
    shift || true
    # shellcheck disable=SC1090
    . "${script_dir}/config.sh"
    case "$sub" in
      show)
        ios_config_show
        ;;
      set)
        ios_config_set "$@"
        ;;
      reset)
        ios_config_reset
        ;;
      *)
        usage
        ;;
    esac
    ;;
  info)
    # Source env.sh to get the ios_show_summary function
    if [ -f "${script_dir}/env.sh" ]; then
      # shellcheck disable=SC1090
      . "${script_dir}/env.sh"
      ios_show_summary
    else
      echo "Error: env.sh not found" >&2
      exit 1
    fi
    ;;
  *)
    usage
    ;;
esac
