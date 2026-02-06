# React Native Plugin Scripts Reference

This document provides a detailed reference for all scripts in the React Native plugin, their purposes, dependencies, and how they interact with each other.

## Scripts Directory Structure

```
devbox/plugins/react-native/scripts/
└── env.sh  # Environment setup and configuration loader (sourced)
```

## Overview

The React Native plugin is intentionally minimal as it primarily serves as a **composition layer** over the Android and iOS plugins. It does not duplicate functionality but rather:

1. Loads React Native-specific configuration
2. Inherits all Android plugin scripts and functions
3. Inherits all iOS plugin scripts and functions
4. Provides a unified environment for cross-platform development

## Detailed Script Documentation

---

### `env.sh`

**Purpose:** Minimal environment initialization script that loads React Native plugin configuration.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Load React Native plugin configuration from `react-native.json` (if exists)
2. Set guard flags to prevent duplicate sourcing
3. Export configuration values as environment variables

**Exported Functions:**
- `load_react_native_config()` - Load configuration from react-native.json

**Key Environment Variables:**
- Any variables defined in `react-native.json` are exported
- Typically includes project-specific settings
- Does not override variables already set in environment

**Configuration Loading:**
- Searches for config in standard locations:
  1. `${REACT_NATIVE_PLUGIN_CONFIG}` (explicit path)
  2. `${REACT_NATIVE_CONFIG_DIR}/react-native.json`
  3. `${DEVBOX_PROJECT_ROOT}/devbox.d/react-native/react-native.json`
  4. `${DEVBOX_PROJECT_DIR}/devbox.d/react-native/react-native.json`
  5. `${DEVBOX_WD}/devbox.d/react-native/react-native.json`
  6. `./devbox.d/react-native/react-native.json`

**Dependencies:**
- `jq` - For JSON parsing

**Called By:**
- Automatically sourced when React Native plugin activates via Devbox

**Guards:**
- Uses `REACT_NATIVE_ENV_LOADED` flag to prevent duplicate sourcing
- Checks PID to handle subshells correctly

**Configuration Format:**
```json
{
  "CUSTOM_VAR": "value",
  "PROJECT_SETTING": "true"
}
```

**Loading Behavior:**
- Only sets variables that are not already defined
- Skips null values
- Exports all loaded variables

---

## Plugin Composition Architecture

The React Native plugin achieves cross-platform support through **plugin composition** in `plugin.json`:

```json
{
  "include": [
    "path:../android/plugin.json",
    "path:../ios/plugin.json"
  ],
  "env": {
    "REACT_NATIVE_CONFIG_DIR": "$DEVBOX_PROJECT_ROOT/devbox.d/react-native"
  }
}
```

### What This Means

1. **All Android Scripts Available:**
   - `android.sh` and all its subcommands
   - `devices.sh` for Android device management
   - AVD management functions from `avd.sh`
   - All Android environment variables

2. **All iOS Scripts Available:**
   - `ios.sh` and all its subcommands
   - `devices.sh` for iOS device management (different namespace)
   - Simulator management functions from `simctl.sh`
   - All iOS environment variables

3. **Unified Device Management:**
   - Android devices: `devbox.d/react-native/devbox.d/android/devices/`
   - iOS devices: `devbox.d/react-native/devbox.d/ios/devices/`
   - Both platforms can be managed independently

4. **Separate Configuration:**
   - Android config: `devbox.d/react-native/devbox.d/android/android.json`
   - iOS config: `devbox.d/react-native/devbox.d/ios/ios.json`
   - React Native config: `devbox.d/react-native/react-native.json`

## Available Commands

Because the React Native plugin includes both Android and iOS plugins, all their commands are available:

### Android Commands
```bash
# Device management
devbox run android.sh devices list
devbox run android.sh devices create pixel_api28 --api 28 --device pixel
devbox run android.sh devices select max
devbox run android.sh devices eval

# Configuration
devbox run android.sh config show
devbox run android.sh config set ANDROID_DEFAULT_DEVICE=max
devbox run android.sh info

# Emulator operations (via scripts provided by Android plugin)
devbox run start-emu [device]
devbox run start-app [device]
devbox run stop-emu
```

### iOS Commands
```bash
# Device management
devbox run ios.sh devices list
devbox run ios.sh devices create iphone15 --runtime 17.5
devbox run ios.sh devices select min max
devbox run ios.sh devices eval

# Configuration
devbox run ios.sh config show
devbox run ios.sh config set IOS_DEFAULT_DEVICE=max
devbox run ios.sh info

# Simulator operations (via scripts provided by iOS plugin)
devbox run start-sim [device]
devbox run start-ios [device]
devbox run stop-sim
```

### React Native-Specific Commands
```bash
# Build all platforms
devbox run build  # Runs build-android, build-ios, build-web

# Platform-specific builds
devbox run build-android
devbox run build-ios
devbox run build-web

# Metro bundler (if configured)
devbox run start  # Start Metro bundler
```

## Script Dependency Graph

```
react-native/env.sh (sourced first)
  └─> Loads react-native.json configuration

android plugin (included)
  ├─> android/env.sh
  ├─> android/lib.sh
  ├─> android/validate.sh
  ├─> android/avd.sh
  ├─> android/android.sh
  ├─> android/devices.sh
  └─> android/select-device.sh

ios plugin (included)
  ├─> ios/env.sh
  ├─> ios/validate.sh
  ├─> ios/simctl.sh
  ├─> ios/ios.sh
  ├─> ios/devices.sh
  └─> ios/select-device.sh
```

## Execution Flow Examples

### Example 1: Starting Android Emulator in React Native Project

```
1. User runs: devbox run start-emu max
2. Android plugin's start-emu script executes
3. Script sources android/env.sh
   3a. android/env.sh loads generated config (from env vars)
   3b. Resolves Android SDK (via Nix or local)
   3c. Sets ANDROID_SDK_ROOT, ANDROID_AVD_HOME, etc.
4. Script sources android/avd.sh
   4a. Loads AVD management functions
5. Emulator starts using device definition from:
   devbox.d/react-native/devbox.d/android/devices/max.json
```

### Example 2: Starting iOS Simulator in React Native Project

```
1. User runs: devbox run start-sim max
2. iOS plugin's start-sim script executes
3. Script sources ios/env.sh
   3a. ios/env.sh loads generated config (from env vars)
   3b. Resolves Xcode developer directory
   3c. Applies devbox_omit_nix_env for native toolchain
   3d. Sets DEVELOPER_DIR, CC, CXX, etc.
4. Script sources ios/simctl.sh
   4a. Loads simulator management functions
5. Simulator starts using device definition from:
   devbox.d/react-native/devbox.d/ios/devices/max.json
```

### Example 3: Building React Native App for Both Platforms

```
1. User runs: devbox run build
2. Devbox executes scripts defined in devbox.json:
   2a. devbox run build-android
       - Android plugin's build script executes
       - Compiles Android APK
   2b. devbox run build-ios
       - iOS plugin's build script executes
       - Compiles iOS .app bundle
   2c. devbox run build-web (if applicable)
       - Web build script executes
       - Bundles web assets
```

### Example 4: Managing Devices for Both Platforms

```
1. Configure Android device:
   devbox run android.sh devices create rn_pixel --api 34 --device pixel

2. Configure iOS device:
   devbox run ios.sh devices create rn_iphone --runtime 17.5

3. Both device definitions stored in React Native project:
   devbox.d/react-native/devbox.d/android/devices/rn_pixel.json
   devbox.d/react-native/devbox.d/ios/devices/rn_iphone.json
```

## Directory Structure in React Native Projects

```
your-react-native-app/
├── devbox.json          # Includes react-native plugin
├── devbox.d/
│   ├── android/         # Android-specific configuration (nested)
│   │   ├── devices/
│   │   │   ├── min.json
│   │   │   └── max.json
│   │   ├── devices.lock.json
│   │   └── flake.nix
│   ├── ios/            # iOS-specific configuration (nested)
│   │   ├── devices/
│   │   │   ├── min.json
│   │   │   └── max.json
│   │   └── devices.lock.json
│   └── react-native/   # React Native configuration (optional)
│       └── react-native.json
├── .devbox/virtenv/     # Generated config files
│   ├── android/
│   │   └── android.json  # Generated from env vars
│   └── ios/
│       └── ios.json      # Generated from env vars
├── android/            # Android project files
├── ios/               # iOS project files
└── package.json       # Node.js dependencies
```

## Configuration Files

### React Native Config (`react-native.json`)

Optional configuration file for React Native-specific settings:

```json
{
  "METRO_PORT": "8081",
  "REACT_NATIVE_PACKAGER_HOSTNAME": "localhost",
  "CUSTOM_PROJECT_SETTING": "value"
}
```

**When to use:**
- Project-wide settings that apply to both platforms
- Metro bundler configuration
- Custom environment variables
- Build flags or feature toggles

**When NOT to use:**
- Platform-specific settings (use env vars in `plugin.json`)
- SDK paths (managed by platform plugins)
- Device definitions (use platform device directories)

### Android Configuration

Android-specific settings are configured via environment variables in `plugin.json`. These are automatically converted to JSON in `.devbox/virtenv/android/android.json` for internal use by the Nix flake.

Example env vars:
```json
{
  "ANDROID_DEFAULT_DEVICE": "max",
  "ANDROID_APP_APK": "android/app/build/outputs/apk/debug/app-debug.apk",
  "ANDROID_BUILD_TOOLS_VERSION": "34.0.0",
  "EVALUATE_DEVICES": ["min", "max"]
}
```

### iOS Configuration

iOS-specific settings are configured via environment variables in `plugin.json`. These are automatically converted to JSON in `.devbox/virtenv/ios/ios.json` for internal use.

```json
{
  "IOS_DEFAULT_DEVICE": "max",
  "IOS_APP_PROJECT": "ios/YourApp.xcodeproj",
  "IOS_APP_SCHEME": "YourApp",
  "IOS_DEFAULT_RUNTIME": "17.5",
  "EVALUATE_DEVICES": ["min", "max"]
}
```

## Environment Variables

### React Native-Specific
- `REACT_NATIVE_CONFIG_DIR` - React Native config directory
- `REACT_NATIVE_PLUGIN_CONFIG` - Explicit config file path
- Any variables from `react-native.json`

### Inherited from Android Plugin
- `ANDROID_SDK_ROOT` - Android SDK path
- `ANDROID_HOME` - Android home (compatibility)
- `ANDROID_AVD_HOME` - AVD storage location
- `ANDROID_DEFAULT_DEVICE` - Default emulator
- All other Android environment variables

### Inherited from iOS Plugin
- `DEVELOPER_DIR` - Xcode developer directory
- `IOS_DEFAULT_DEVICE` - Default simulator
- `IOS_DEFAULT_RUNTIME` - Default iOS runtime
- `CC`, `CXX` - Compiler paths (macOS only)
- All other iOS environment variables

## Common Workflows

### Development Workflow

```bash
# 1. Start Metro bundler
devbox run start

# 2. In another terminal, start Android emulator
devbox run start-emu max

# 3. Build and launch Android app
devbox run start-app max

# 4. Or start iOS simulator (macOS only)
devbox run start-sim max

# 5. Build and launch iOS app
devbox run start-ios max
```

### CI/CD Workflow

```bash
# Android CI
devbox run android.sh devices select max
devbox run android.sh devices eval
EMU_HEADLESS=1 devbox run --pure start-emu max
devbox run --pure build-android
devbox run --pure stop-emu

# iOS CI (macOS only)
devbox run ios.sh devices select max
devbox run ios.sh devices eval
SIM_HEADLESS=1 devbox run --pure start-sim max
devbox run --pure build-ios
devbox run --pure stop-sim
```

### Testing Both Platforms

```bash
# Run Android tests
devbox run android.sh devices select min max
devbox run test-android

# Run iOS tests (macOS only)
devbox run ios.sh devices select min max
devbox run test-ios
```

## Best Practices

### 1. Device Naming Conventions
Use consistent naming across platforms:
```bash
# Good: Clear platform prefix
devbox run android.sh devices create rn-min --api 21 --device pixel
devbox run ios.sh devices create rn-min --runtime 15.4

# Better: Use generic names if semantics match
devbox run android.sh devices create min --api 21 --device pixel
devbox run ios.sh devices create min --runtime 15.4
```

### 2. Configuration Management
Keep platform-specific settings in environment variables in `plugin.json`:
```bash
# ✓ Good: Android-specific env vars in plugin.json
ANDROID_DEFAULT_DEVICE=pixel_api34

# ✓ Good: iOS-specific env vars in plugin.json
IOS_DEFAULT_DEVICE=iphone15

# ✗ Bad: Don't put platform settings in react-native.json
ANDROID_DEFAULT_DEVICE=pixel_api34  # Wrong file!
```

### 3. Lock File Management
Generate lock files for both platforms in CI:
```bash
# Always run both
devbox run android.sh devices eval
devbox run ios.sh devices eval

# Commit both lock files
git add devbox.d/android/devices.lock.json
git add devbox.d/ios/devices.lock.json
```

### 4. Script Organization
Use Devbox scripts in `devbox.json` for React Native-specific tasks:
```json
{
  "shell": {
    "scripts": {
      "start": "npx react-native start",
      "build": ["build-android", "build-ios"],
      "build-android": "cd android && ./gradlew assembleDebug",
      "build-ios": "xcodebuild -workspace ios/App.xcworkspace -scheme App -configuration Debug",
      "test": ["test-android", "test-ios"],
      "test-android": "cd android && ./gradlew test",
      "test-ios": "xcodebuild test -workspace ios/App.xcworkspace -scheme App"
    }
  }
}
```

### 5. Platform Detection in Scripts
When writing custom scripts, detect platform:
```bash
#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"

case "$platform" in
  android)
    devbox run start-emu
    devbox run start-app
    ;;
  ios)
    if [ "$(uname -s)" != "Darwin" ]; then
      echo "iOS requires macOS" >&2
      exit 1
    fi
    devbox run start-sim
    devbox run start-ios
    ;;
  *)
    echo "Usage: $0 {android|ios}" >&2
    exit 1
    ;;
esac
```

## Debugging

### Enable Debug Mode for All Plugins
```bash
DEBUG=1 devbox shell
```

### Enable Platform-Specific Debug
```bash
# Android only
ANDROID_DEBUG=1 devbox shell

# iOS only
IOS_DEBUG=1 devbox shell

# Both
ANDROID_DEBUG=1 IOS_DEBUG=1 devbox shell
```

### Check Platform Configurations
```bash
# View Android config
devbox run android.sh info

# View iOS config
devbox run ios.sh info

# View both
devbox run android.sh info && devbox run ios.sh info
```

### Verify Device Definitions
```bash
# List Android devices
devbox run android.sh devices list

# List iOS devices
devbox run ios.sh devices list
```

## Troubleshooting

### Issue: "android.sh: command not found"
**Cause:** Android plugin not properly included

**Solution:**
```bash
# Check devbox.json includes android plugin
cat devbox.json | grep -A5 include

# Should show:
# "include": ["path:../../plugins/react-native/plugin.json"]

# Restart shell
devbox shell
```

### Issue: "iOS commands not working on macOS"
**Cause:** iOS plugin requires Xcode

**Solution:**
```bash
# Install Xcode from App Store
# Then install command-line tools
xcode-select --install

# Verify installation
devbox run ios.sh info
```

### Issue: "Devices from different plugins conflict"
**Cause:** Device names might conflict if not carefully managed

**Solution:**
- Android and iOS have separate device directories, so same names are OK
- Each platform reads from its own `devbox.d/{platform}/devices/`
- No actual conflict, but naming clearly helps debugging

### Issue: "Environment variables from both plugins conflict"
**Cause:** Rare, as plugins use namespaced variables

**Solution:**
- Android uses `ANDROID_*` prefix
- iOS uses `IOS_*` prefix
- No common variables should conflict
- If custom config adds conflicts, use distinct names

## Advanced: Custom Plugin Extensions

You can extend the React Native plugin with custom scripts:

```
your-react-native-app/
├── devbox.d/
│   └── react-native/
│       └── scripts/
│           ├── env.sh (optional overrides)
│           └── custom-deploy.sh (your script)
└── devbox.json
```

Add to PATH in `devbox.json`:
```json
{
  "env": {
    "PATH": "$DEVBOX_PROJECT_ROOT/devbox.d/react-native/scripts:$PATH"
  }
}
```

Then call your custom scripts:
```bash
devbox run custom-deploy.sh
```

## Relationship to Platform Plugins

**Key Principle:** React Native plugin does NOT duplicate or override platform plugins. It:

1. **Composes** Android and iOS plugins
2. **Delegates** all platform operations to respective plugins
3. **Adds** React Native-specific configuration loading
4. **Provides** unified project structure

**Result:** You get the full power of both Android and iOS plugins with minimal overhead and a unified development experience.

For detailed information about platform-specific scripts, see:
- [Android Plugin Scripts Reference](../android/SCRIPTS.md)
- [iOS Plugin Scripts Reference](../ios/SCRIPTS.md)
