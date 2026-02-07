#!/usr/bin/env sh
set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: validate.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_VALIDATE_LOADED:-}" = "1" ] && [ "${IOS_VALIDATE_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_VALIDATE_LOADED=1
IOS_VALIDATE_LOADED_PID="$$"

# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

ios_validate_xcode() {
  # Only validate on macOS
  if [ "$(uname -s)" != "Darwin" ]; then
    return 0
  fi

  # Check if xcode-select exists (env.sh adds /usr/bin to PATH)
  if ! command -v xcode-select >/dev/null 2>&1; then
    echo "Warning: xcode-select not found. Install Xcode from the App Store." >&2
    return 0
  fi

  # Check developer directory
  dev_dir=$(xcode-select -p 2>/dev/null || true)

  if [ -z "$dev_dir" ] || [ ! -d "$dev_dir" ]; then
    echo "Warning: Xcode developer directory not found. Run 'xcode-select --install' or install Xcode from the App Store." >&2
    return 0
  fi

  # Success - Xcode or Nix SDK is available (dev_dir could be /nix/store/... or /Applications/Xcode.app/...)
  return 0
}

