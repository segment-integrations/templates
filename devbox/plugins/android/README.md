# Android Devbox Plugin

This plugin pins Android user data (AVDs, emulator configs, adb keys) to the project virtenv so
shells are pure and do not touch global `~/.android` state.

Runtime scripts live in the virtenv (`.devbox/virtenv/android/scripts`) and are added to PATH when
the plugin activates.

Default configuration lives at `devbox.d/android/android.json`. Override values there to set SDK
versions, default device selection, or enable `ANDROID_LOCAL_SDK`. The plugin initializes
`android.json` and the flake files on first activation.

The Android SDK flake lives under `devbox.d/android/` and exposes `android-sdk*` outputs.

## Quickstart

```sh
# List devices
devbox run --pure android.sh devices list

# Boot emulator (device name is the file name or the "name" field)
devbox run --pure start-emu max

# Build + install + launch on the resolved emulator
devbox run --pure start-android max
```

`start-android` runs `devbox run --pure build-android` in the project and installs the APK matched by
`ANDROID_APP_APK`.

## Reference

See `devbox/plugins/android/REFERENCE.md` for the full command and config reference.

## Device definitions

Device definitions live in `devbox.d/android/devices/*.json`. Each file can include:
- `name` (string)
- `api` (number, required)
- `device` (AVD device id, required)
- `tag` (e.g. `google_apis`, `google_apis_playstore`, `play_store`, `aosp_atd`, `google_atd`)
- `preferred_abi` (e.g. `arm64-v8a`, `x86_64`, `x86`)

Default devices are `min.json` and `max.json`.

## Selecting devices for evaluation

The flake evaluates all device APIs by default. To restrict it, set:
```json
{"EVALUATE_DEVICES": ["max"]}
```
Use `devbox run --pure android.sh devices select max` to update this value.

## Commands

Device commands:
```sh
devbox run --pure android.sh devices list
devbox run --pure android.sh devices create pixel_api28 --api 28 --device pixel --tag google_apis
devbox run --pure android.sh devices update pixel_api28 --api 29
devbox run --pure android.sh devices delete pixel_api28
devbox run --pure android.sh devices reset
devbox run --pure android.sh devices eval
```

Config commands:
```sh
devbox run --pure android.sh config show
devbox run --pure android.sh config set ANDROID_DEFAULT_DEVICE=max
devbox run --pure android.sh config reset
```

## Environment variables

- `ANDROID_CONFIG_DIR` — project config directory (`devbox.d/android`)
- `ANDROID_DEVICES_DIR` — device definitions directory
- `ANDROID_SCRIPTS_DIR` — runtime scripts directory (`.devbox/virtenv/android/scripts`)
- `ANDROID_DEFAULT_DEVICE` — used when no device name is provided
- `EVALUATE_DEVICES` — list of device names to evaluate in the flake (empty means all)
- `ANDROID_APP_APK` — APK path or glob pattern (relative to project root) used for install/launch
