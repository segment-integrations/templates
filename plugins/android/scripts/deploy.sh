#!/usr/bin/env sh
# Android Plugin - Application Deployment
# See SCRIPTS.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: deploy.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_DEPLOY_LOADED:-}" = "1" ] && [ "${ANDROID_DEPLOY_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_DEPLOY_LOADED=1
ANDROID_DEPLOY_LOADED_PID="$$"

# Source dependencies
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib.sh"
  . "${ANDROID_SCRIPTS_DIR}/core.sh"
  . "${ANDROID_SCRIPTS_DIR}/emulator.sh"
fi

# Run Android project build via devbox
android_run_build() {
  project_root="$1"

  if ! command -v devbox >/dev/null 2>&1; then
    echo "ERROR: devbox is required to run the project build" >&2
    return 1
  fi

  echo "Building Android project: $project_root"
  (cd "$project_root" && devbox run --pure build-android)
}

# Resolve APK path from glob pattern
android_resolve_apk_path() {
  project_root="$1"
  apk_pattern="$2"

  if [ -z "$apk_pattern" ]; then
    return 1
  fi

  # Make pattern absolute if it's relative
  if [ "${apk_pattern#/}" = "$apk_pattern" ]; then
    apk_pattern="${project_root%/}/$apk_pattern"
  fi

  # Find matching APK files
  # Temporarily disable glob failure to check if any files match
  set +f
  matched_apks=""
  for apk_candidate in $apk_pattern; do
    if [ -f "$apk_candidate" ]; then
      matched_apks="${matched_apks}${matched_apks:+
}$apk_candidate"
    fi
  done
  set -f

  if [ -z "$matched_apks" ]; then
    return 1
  fi

  # Count matches
  match_count="$(printf '%s\n' "$matched_apks" | wc -l | tr -d ' ')"
  if [ "$match_count" -gt 1 ]; then
    echo "WARNING: Multiple APKs matched pattern: $apk_pattern" >&2
    echo "         Using first match" >&2
  fi

  # Return first match
  printf '%s\n' "$matched_apks" | head -n1
}

# Find aapt tool from Android SDK (PATH > SDK/build-tools)
android_resolve_aapt() {
  # Priority 1: aapt in PATH
  if command -v aapt >/dev/null 2>&1; then
    printf '%s\n' "aapt"
    return 0
  fi

  # Priority 2 & 3: Search in SDK build-tools
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    # Try specific version if set
    if [ -n "${ANDROID_BUILD_TOOLS_VERSION:-}" ]; then
      aapt_path="${ANDROID_SDK_ROOT%/}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}/aapt"
      if [ -x "$aapt_path" ]; then
        printf '%s\n' "$aapt_path"
        return 0
      fi
    fi

    # Try to find latest version
    aapt_path="$(find "${ANDROID_SDK_ROOT%/}/build-tools" -type f -name aapt 2>/dev/null | sort | tail -n1)"
    if [ -n "$aapt_path" ] && [ -x "$aapt_path" ]; then
      printf '%s\n' "$aapt_path"
      return 0
    fi
  fi

  return 1
}

# Extract app metadata from APK using aapt
android_extract_apk_metadata() {
  apk_path="$1"

  # Find aapt tool
  aapt_tool="$(android_resolve_aapt || true)"
  if [ -z "$aapt_tool" ]; then
    echo "ERROR: Unable to locate aapt tool" >&2
    echo "       Ensure Android build-tools are installed" >&2
    return 1
  fi

  # Dump APK badging
  apk_badging="$("$aapt_tool" dump badging "$apk_path" 2>/dev/null || true)"
  if [ -z "$apk_badging" ]; then
    echo "ERROR: Failed to read APK metadata from: $apk_path" >&2
    return 1
  fi

  # Extract package name
  package_name="$(printf '%s\n' "$apk_badging" | awk -F"'" '/package: name=/{print $2; exit}')"
  package_name="$(printf '%s' "$package_name" | tr -d '\r' | awk '{print $1}')"

  # Extract launchable activity
  activity_name="$(printf '%s\n' "$apk_badging" | awk -F"'" '/launchable-activity: name=/{print $2; exit}')"
  activity_name="$(printf '%s' "$activity_name" | tr -d '\r' | awk '{print $1}')"

  # Validate extraction
  if [ -z "$package_name" ]; then
    echo "ERROR: Unable to read package name from APK: $apk_path" >&2
    return 1
  fi

  if [ -z "$activity_name" ]; then
    echo "ERROR: Unable to resolve launchable activity for package: $package_name" >&2
    return 1
  fi

  # Return metadata (two lines)
  printf '%s\n' "$package_name"
  printf '%s\n' "$activity_name"
}

# Resolve full activity component name (normalize various formats)
android_resolve_activity_component() {
  package_name="$1"
  activity_name="$2"

  # If activity already contains a slash, use as-is
  case "$activity_name" in
    */*)
      printf '%s\n' "$activity_name"
      return 0
      ;;
  esac

  # Otherwise, build component name
  case "$activity_name" in
    .*)
      # Relative activity (e.g., ".MainActivity")
      printf '%s/%s\n' "$package_name" "$activity_name"
      ;;
    "$package_name"*)
      # Full package prefix (e.g., "com.example.app.MainActivity")
      printf '%s/%s\n' "$package_name" "$activity_name"
      ;;
    *)
      # Simple name (e.g., "MainActivity")
      printf '%s/%s\n' "$package_name" "$activity_name"
      ;;
  esac
}

# Install APK on emulator
android_install_apk() {
  apk_path="$1"
  emulator_serial="$2"

  echo "Installing APK: $(basename "$apk_path")"

  adb -s "$emulator_serial" wait-for-device
  adb -s "$emulator_serial" install -r "$apk_path" >/dev/null

  echo "✓ APK installed"
}

# Launch app on emulator (tries activity manager, falls back to monkey)
android_launch_app() {
  package_name="$1"
  activity_name="$2"
  emulator_serial="$3"

  echo "Launching app: $package_name"

  # Build full component name
  component_name="$(android_resolve_activity_component "$package_name" "$activity_name")"

  android_debug_log "Launch component: $component_name"

  # Try launching via activity manager
  if adb -s "$emulator_serial" shell am start -n "$component_name" >/dev/null 2>&1; then
    echo "✓ App launched via activity manager"
  else
    echo "WARNING: Activity manager launch failed, trying monkey launcher" >&2

    # Fallback: Use monkey to launch via launcher intent
    adb -s "$emulator_serial" shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
  fi

  # Verify app process is running
  if adb -s "$emulator_serial" shell pidof "$package_name" >/dev/null 2>&1; then
    echo "✓ App process running"
  else
    echo "WARNING: App process not detected after launch attempt" >&2
    echo "         App may still have launched successfully" >&2
  fi
}

# Deploy Android app (build, install, launch)
android_deploy_app() {
  device_choice="${1:-}"

  # ---- Resolve Device Selection ----

  # Use provided device, or fall back to environment variables
  if [ -z "$device_choice" ] && [ -n "${ANDROID_DEFAULT_DEVICE:-}" ]; then
    device_choice="$ANDROID_DEFAULT_DEVICE"
  fi
  if [ -z "$device_choice" ]; then
    device_choice="${TARGET_DEVICE:-}"
  fi

  # ---- Regenerate Lock File (if devices CLI available) ----

  if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -x "${ANDROID_SCRIPTS_DIR%/}/devices.sh" ]; then
    "${ANDROID_SCRIPTS_DIR%/}/devices.sh" eval >/dev/null 2>&1 || true
  fi

  # ---- Start Emulator ----

  echo "================================================"
  echo "Android App Deployment"
  echo "================================================"
  echo ""

  android_start_emulator "$device_choice"

  # ---- Resolve Project Root ----

  project_root="${DEVBOX_PROJECT_ROOT:-${DEVBOX_PROJECT_DIR:-${DEVBOX_WD:-$PWD}}}"
  if [ -z "$project_root" ] || [ ! -d "$project_root" ]; then
    echo "ERROR: Unable to resolve project root for Android build" >&2
    exit 1
  fi

  echo ""
  echo "Project root: $project_root"

  # ---- Build App ----

  echo ""
  android_run_build "$project_root"

  # ---- Find APK ----

  echo ""
  echo "Locating APK..."

  apk_pattern="${ANDROID_APP_APK:-app/build/outputs/apk/debug/*.apk}"
  apk_path="$(android_resolve_apk_path "$project_root" "$apk_pattern" || true)"

  if [ -z "$apk_path" ] || [ ! -f "$apk_path" ]; then
    echo "ERROR: Unable to locate APK" >&2
    echo "       Pattern: $apk_pattern" >&2
    echo "       Set ANDROID_APP_APK to correct path or pattern" >&2
    exit 1
  fi

  echo "Found APK: $(basename "$apk_path")"

  # ---- Extract Metadata ----

  echo ""
  echo "Extracting app metadata..."

  apk_metadata="$(android_extract_apk_metadata "$apk_path")"
  package_name="$(printf '%s\n' "$apk_metadata" | sed -n '1p')"
  activity_name="$(printf '%s\n' "$apk_metadata" | sed -n '2p')"

  echo "  Package: $package_name"
  echo "  Activity: $activity_name"

  # ---- Deploy to Emulator ----

  emulator_serial="${ANDROID_EMULATOR_SERIAL:-emulator-${EMU_PORT:-5554}}"

  echo ""
  echo "Deploying to: $emulator_serial"
  echo ""

  android_install_apk "$apk_path" "$emulator_serial"
  echo ""
  android_launch_app "$package_name" "$activity_name" "$emulator_serial"

  echo ""
  echo "================================================"
  echo "✓ Deployment complete!"
  echo "================================================"
}
