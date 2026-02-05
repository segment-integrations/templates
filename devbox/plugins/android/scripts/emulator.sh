#!/usr/bin/env sh
# Android Plugin - Emulator Lifecycle Management
# See SCRIPTS.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: emulator.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_EMULATOR_LOADED:-}" = "1" ] && [ "${ANDROID_EMULATOR_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_EMULATOR_LOADED=1
ANDROID_EMULATOR_LOADED_PID="$$"

# Find a running emulator by AVD name
android_find_running_emulator() {
  avd_name="$1"

  if ! command -v adb >/dev/null 2>&1; then
    return 1
  fi

  # Check all running emulator serials
  for emulator_serial in $(adb devices | awk 'NR>1 && $1 ~ /^emulator-/{print $1}'); do
    # Query the AVD name from the emulator
    running_avd_name="$(adb -s "$emulator_serial" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d "\r")"

    if [ -n "$running_avd_name" ] && [ "$running_avd_name" = "$avd_name" ]; then
      printf '%s\n' "$emulator_serial"
      return 0
    fi
  done

  return 1
}

# Find an available emulator port (even numbers: 5554, 5556, 5558, ...)
android_find_available_port() {
  starting_port="${1:-5554}"
  candidate_port="$starting_port"

  if ! command -v adb >/dev/null 2>&1; then
    printf '%s\n' "$candidate_port"
    return 0
  fi

  # Keep incrementing by 2 until we find an unused port
  while adb devices | awk 'NR>1 && $1=="emulator-'"$candidate_port"'"' | grep -q .; do
    candidate_port=$((candidate_port + 2))
  done

  printf '%s\n' "$candidate_port"
}

# Clean up offline emulator entries in adb
android_cleanup_offline_emulators() {
  if ! command -v adb >/dev/null 2>&1; then
    return 0
  fi

  adb devices | awk 'NR>1 && $2=="offline" {print $1}' | while read -r offline_serial; do
    adb -s "$offline_serial" emu kill >/dev/null 2>&1 || true
  done
}

# Start an Android emulator
android_start_emulator() {
  device_name="${1:-}"

  # Set device selection if provided
  if [ -n "$device_name" ]; then
    ANDROID_DEVICE_NAME="$device_name"
    export ANDROID_DEVICE_NAME
  fi

  # Configuration
  headless_mode="${EMU_HEADLESS:-}"
  preferred_port="${EMU_PORT:-5554}"
  avd_to_start=""

  # ---- Setup AVDs ----

  echo "Setting up Android Virtual Devices..."
  android_setup_avds

  # ---- Resolve AVD Name ----

  # Priority order: user-specified AVD > resolved AVD from setup > error
  if [ -n "${AVD_NAME:-}" ]; then
    avd_to_start="$AVD_NAME"
  elif [ -n "${ANDROID_RESOLVED_AVD:-}" ]; then
    avd_to_start="$ANDROID_RESOLVED_AVD"
  fi

  if [ -z "$avd_to_start" ]; then
    echo "ERROR: No AVD resolved" >&2
    echo "       Set ANDROID_DEVICE_NAME or AVD_NAME explicitly" >&2
    exit 1
  fi

  echo ""
  echo "Target AVD: $avd_to_start"

  # ---- Check if Already Running ----

  android_cleanup_offline_emulators

  existing_serial="$(android_find_running_emulator "$avd_to_start" 2>/dev/null || true)"
  if [ -n "$existing_serial" ]; then
    ANDROID_EMULATOR_SERIAL="$existing_serial"
    export ANDROID_EMULATOR_SERIAL

    # Extract port from serial (emulator-5554 -> 5554)
    EMU_PORT="${existing_serial#emulator-}"
    export EMU_PORT

    echo "Android emulator already running: ${existing_serial} (${avd_to_start})"
    return 0
  fi

  # ---- Find Available Port ----

  available_port="$(android_find_available_port "$preferred_port")"
  emulator_serial="emulator-${available_port}"

  ANDROID_EMULATOR_SERIAL="$emulator_serial"
  EMU_PORT="$available_port"
  export ANDROID_EMULATOR_SERIAL EMU_PORT

  # ---- Start Emulator ----

  echo ""
  echo "Starting Android emulator:"
  echo "  AVD: $avd_to_start"
  echo "  Port: $available_port"
  echo "  Serial: $emulator_serial"
  echo "  Headless: ${headless_mode:-no}"

  # Build emulator command
  emulator_flags="-port $available_port"
  emulator_flags="$emulator_flags -gpu swiftshader_indirect"
  emulator_flags="$emulator_flags -noaudio"
  emulator_flags="$emulator_flags -no-boot-anim"
  emulator_flags="$emulator_flags -camera-back none"
  emulator_flags="$emulator_flags -accel on"
  emulator_flags="$emulator_flags -writable-system"
  emulator_flags="$emulator_flags -no-snapshot-save"

  if [ -n "$headless_mode" ]; then
    emulator_flags="$emulator_flags -no-window"
  fi

  # Start emulator in background
  # shellcheck disable=SC2086
  emulator -avd "$avd_to_start" $emulator_flags &
  emulator_pid="$!"

  EMULATOR_PID="$emulator_pid"
  export EMULATOR_PID

  echo "  PID: $emulator_pid"

  # ---- Wait for Device ----

  echo ""
  echo "Waiting for emulator to be ready..."

  if ! command -v adb >/dev/null 2>&1; then
    echo "WARNING: adb not found, cannot verify emulator status" >&2
    return 0
  fi

  adb -s "$emulator_serial" wait-for-device

  # ---- Wait for Boot Completion ----

  echo "Waiting for boot to complete..."

  boot_completed=""
  max_wait_seconds=300  # 5 minutes
  elapsed_seconds=0

  until [ "$boot_completed" = "1" ]; do
    boot_completed=$(adb -s "$emulator_serial" shell getprop sys.boot_completed 2>/dev/null | tr -d "\r")

    if [ "$elapsed_seconds" -ge "$max_wait_seconds" ]; then
      echo "WARNING: Boot timeout after ${max_wait_seconds}s, continuing anyway" >&2
      break
    fi

    sleep 5
    elapsed_seconds=$((elapsed_seconds + 5))
  done

  # ---- Optimize for Testing ----

  echo "Disabling animations for faster testing..."

  adb -s "$emulator_serial" shell settings put global window_animation_scale 0 2>/dev/null || true
  adb -s "$emulator_serial" shell settings put global transition_animation_scale 0 2>/dev/null || true
  adb -s "$emulator_serial" shell settings put global animator_duration_scale 0 2>/dev/null || true

  echo ""
  echo "✓ Emulator ready: $emulator_serial"
}

# Run emulator as a service (blocks until stopped)
android_run_emulator_service() {
  device_name="${1:-}"

  # Start the emulator
  android_start_emulator "$device_name"

  # Setup signal handler to stop emulator on interrupt
  trap 'android_stop_emulator; exit 0' INT TERM

  echo ""
  echo "Emulator running in service mode"
  echo "Press Ctrl+C to stop"
  echo ""

  # Keep running while emulator process is alive
  if [ -n "${EMULATOR_PID:-}" ]; then
    while kill -0 "$EMULATOR_PID" 2>/dev/null; do
      sleep 5
    done
    echo "Emulator process ended"
  else
    # If we don't have PID, just sleep forever
    while true; do
      sleep 5
    done
  fi
}

# Stop all running Android emulators
android_stop_emulator() {
  echo "Stopping Android emulators..."

  # Clean up offline entries
  android_cleanup_offline_emulators

  if ! command -v adb >/dev/null 2>&1; then
    echo "WARNING: adb not found, trying process kill only" >&2
  else
    # Get list of all running emulator serials
    running_emulators="$(adb devices -l 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' ' ')"

    if [ -n "$running_emulators" ]; then
      echo "Stopping emulators: $running_emulators"
      for emulator_serial in $running_emulators; do
        adb -s "$emulator_serial" emu kill >/dev/null 2>&1 || true
      done
    else
      echo "No emulators detected via adb"
    fi
  fi

  # Kill any remaining emulator processes
  # Pattern "emulator@" is used by emulator process names
  pkill -f "emulator@" >/dev/null 2>&1 || true

  echo "✓ Android emulators stopped"
}
