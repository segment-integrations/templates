# Android Devbox Plugin Reference

## Files

- `.devbox/virtenv/android/android.json` — generated config (created from env vars for Nix flake evaluation)
- `devbox.d/android/devices/*.json` — device definitions
- `devbox.d/android/devices.lock.json` — resolved API list for the SDK flake
- `.devbox/virtenv/android/scripts` — runtime scripts (added to PATH)
- `devbox.d/android/flake.nix` — SDK flake (device APIs drive evaluation)

## Device definition schema

Each device file is JSON with:
- `name` (string, required)
- `api` (number, required)
- `device` (AVD device id, required)
- `tag` (string, optional; e.g. `google_apis`, `google_apis_playstore`, `play_store`, `aosp_atd`, `google_atd`)
- `preferred_abi` (string, optional; `arm64-v8a`, `x86_64`, `x86`)

## Configuration (Environment Variables)

Configure the plugin by setting environment variables in `plugin.json`. These are automatically converted to JSON for internal use by the Nix flake.

- `ANDROID_LOCAL_SDK` — Use local SDK instead of Nix-managed SDK (0=false, 1=true)
- `ANDROID_COMPILE_SDK` — Compile SDK version (e.g., "36")
- `ANDROID_TARGET_SDK` — Target SDK version (e.g., "36")
- `EVALUATE_DEVICES` — Array of device names to evaluate in flake (empty = all devices)
- `ANDROID_DEFAULT_DEVICE` — Default device name when none specified
- `ANDROID_SYSTEM_IMAGE_TAG` — System image tag (e.g., "google_apis", "google_apis_playstore")
- `ANDROID_APP_APK` — Path or glob pattern for APK (relative to project root)
- `ANDROID_BUILD_TOOLS_VERSION` — Build tools version (e.g., "36.1.0")
- `ANDROID_INCLUDE_NDK` — Include Android NDK in SDK (true/false, default: false)
- `ANDROID_NDK_VERSION` — NDK version when enabled (e.g., "27.0.12077973")
- `ANDROID_INCLUDE_CMAKE` — Include CMake in SDK (true/false, default: false)
- `ANDROID_CMAKE_VERSION` — CMake version when enabled (e.g., "3.22.1")
- `ANDROID_CMDLINE_TOOLS_VERSION` — Command-line tools version (e.g., "19.0")

## Commands

### Emulator

- `devbox run --pure start-emu [device]`
- `devbox run --pure stop-emu`

### Build + run

- `devbox run --pure start-android [device]`
  - Runs `devbox run --pure build-android` in the project and installs the APK matched by `ANDROID_APP_APK`.

### Device management

- `devbox run --pure android.sh devices list`
- `devbox run --pure android.sh devices show <name>`
- `devbox run --pure android.sh devices create <name> --api <n> --device <id> [--tag <tag>] [--abi <abi>]`
- `devbox run --pure android.sh devices update <name> [--name <new>] [--api <n>] [--device <id>] [--tag <tag>] [--abi <abi>]`
- `devbox run --pure android.sh devices delete <name>`
- `devbox run --pure android.sh devices select <name...>`
- `devbox run --pure android.sh devices reset`
- `devbox run --pure android.sh devices eval`

### Config management

- `devbox run --pure android.sh config show`
- `devbox run --pure android.sh config set KEY=VALUE [KEY=VALUE...]`
- `devbox run --pure android.sh config reset`

## Environment variables

- `ANDROID_CONFIG_DIR`
- `ANDROID_DEVICES_DIR`
- `ANDROID_SCRIPTS_DIR`
- `ANDROID_DEFAULT_DEVICE`
- `EVALUATE_DEVICES`
- `ANDROID_APP_APK`
- `EMU_HEADLESS`
- `EMU_PORT`
- `ANDROID_DEVICE_NAME`
- `TARGET_DEVICE`
