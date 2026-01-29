#!/usr/bin/env sh

if ! (return 0 2>/dev/null); then
  echo "devbox.d/android/scripts/lib.sh must be sourced." >&2
  exit 1
fi

if [ "${ANDROID_LIB_LOADED:-}" = "1" ] && [ "${ANDROID_LIB_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_LIB_LOADED=1
ANDROID_LIB_LOADED_PID="$$"

android_normalize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

android_sanitize_avd_name() {
  raw="$1"
  if [ -z "$raw" ]; then
    return 1
  fi
  cleaned="$(printf '%s' "$raw" | tr ' ' '_' | tr -cd 'A-Za-z0-9._-')"
  if [ -z "$cleaned" ]; then
    return 1
  fi
  printf '%s\n' "$cleaned"
}
