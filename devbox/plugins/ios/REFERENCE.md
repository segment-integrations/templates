# iOS Devbox Plugin Reference

## Files

- `devbox.d/ios/ios.json` — project config (generated on first activation)
- `devbox.d/ios/devices/*.json` — simulator definitions
- `.devbox/virtenv/ios/scripts` — runtime scripts (added to PATH)

## Device definition schema

Each device file is JSON with:
- `name` (string, required)
- `runtime` (string, required; e.g. `15.4`, `26.2`)

## Config keys (`ios.json`)

- `IOS_RUNTIME_MIN`
- `IOS_RUNTIME_MAX`
- `IOS_RUNTIME_CUSTOM`
- `IOS_MIN_DEVICE`
- `IOS_MAX_DEVICE`
- `IOS_CUSTOM_DEVICE`
- `IOS_DEVICE_NAMES`
- `IOS_DEFAULT_DEVICE`
- `IOS_DEVELOPER_DIR`
- `IOS_DOWNLOAD_RUNTIME`
- `IOS_XCODE_ENV_PATH`

## Commands

### Simulator

- `devbox run --pure start-sim [device]`
- `devbox run --pure stop-sim`

## Environment variables

- `IOS_CONFIG_DIR`
- `IOS_DEVICES_DIR`
- `IOS_SCRIPTS_DIR`
- `IOS_DEFAULT_DEVICE`
- `SIM_HEADLESS`
- `IOS_DEVICE_NAME`
