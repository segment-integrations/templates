# Android Devbox Plugin Reference

## Files

- `devbox.d/android/android.json` — project config (generated on first activation)
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

## Config keys (`android.json`)

- `ANDROID_SDK_FLAKE_OUTPUT`
- `ANDROID_SDK_FLAKE_PATH`
- `ANDROID_LOCAL_SDK`
- `ANDROID_SDK_ROOT`
- `ANDROID_HOME`
- `ANDROID_COMPILE_SDK`
- `ANDROID_TARGET_SDK`
- `ANDROID_PLATFORM_VERSIONS` (array; extra SDK platforms to include)
- `EVALUATE_DEVICES` (array; empty means all)
- `ANDROID_DEFAULT_DEVICE`
- `ANDROID_SYSTEM_IMAGE_TAG`
- `ANDROID_APP_APK` (path or glob relative to project root)
- `ANDROID_BUILD_TOOLS_VERSION`
- `ANDROID_NDK_VERSION`
- `ANDROID_CMAKE_VERSION` (string; preferred CMake version)
- `ANDROID_CMAKE_VERSIONS` (array; empty to skip CMake)
- `ANDROID_CMDLINE_TOOLS_VERSION`

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
