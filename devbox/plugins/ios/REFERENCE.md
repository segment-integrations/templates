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

- `EVALUATE_DEVICES`
- `IOS_DEFAULT_DEVICE`
- `IOS_DEFAULT_RUNTIME`
- `IOS_APP_PROJECT`
- `IOS_APP_SCHEME`
- `IOS_APP_BUNDLE_ID`
- `IOS_APP_ARTIFACT` (path or glob relative to project root)
- `IOS_APP_DERIVED_DATA`
- `IOS_DEVELOPER_DIR`
- `IOS_DOWNLOAD_RUNTIME`
- `IOS_XCODE_ENV_PATH`

## Commands

### Simulator

- `devbox run --pure start-sim [device]`
- `devbox run --pure stop-sim`
- `devbox run --pure start-ios [device]`

`start-ios` runs `devbox run --pure build-ios` in the project, then installs the app bundle matched by
`IOS_APP_ARTIFACT`. If `IOS_APP_BUNDLE_ID` is not set, the bundle identifier is read from the app's
`Info.plist`.
- `devbox run --pure ios.sh devices <command>`
- `devbox run --pure ios.sh config <command>`

## Environment variables

- `IOS_CONFIG_DIR`
- `IOS_DEVICES_DIR`
- `IOS_SCRIPTS_DIR`
- `IOS_DEFAULT_DEVICE`
- `EVALUATE_DEVICES`
- `SIM_HEADLESS`
- `IOS_DEVICE_NAME`
