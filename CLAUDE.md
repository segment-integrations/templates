# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a mobile development templates repository providing Devbox plugins and example projects for Android, iOS, and React Native. The plugins enable project-local, reproducible mobile development environments without touching global state (e.g., `~/.android`).

## Core Architecture

### Plugin System

Three main plugins are located in `devbox/plugins/`:

1. **android** - Android SDK + emulator management via Nix flake
   - SDK flake: `devbox.d/android/flake.nix`
   - Device definitions: `devbox.d/android/devices/*.json`
   - Scripts: `.devbox/virtenv/android/scripts/`
   - Configuration: Environment variables in `plugin.json`

2. **ios** - iOS toolchain + simulator management for macOS
   - Device definitions: `devbox.d/ios/devices/*.json`
   - Scripts: `.devbox/virtenv/ios/scripts/`
   - Configuration: Environment variables in `plugin.json`

3. **react-native** - Composition layer over Android + iOS plugins
   - Inherits both Android and iOS device management
   - Enables cross-platform React Native development

### Key Concepts

**Device Definitions**: JSON files defining emulator/simulator configurations
- Android: `{name, api, device, tag, preferred_abi}`
- iOS: `{name, runtime}`
- Default devices: `min.json` and `max.json`

**Lock Files**: `devices/devices.lock` optimizes CI by limiting which SDK versions are evaluated
- Generated via `{platform}.sh devices eval`
- Contains checksums of device definitions for validation

**Caching**: 1-hour TTL caches for expensive operations
- Android: `.nix_sdk_eval.cache` (Nix flake evaluation)
- iOS: `.xcode_dev_dir.cache`, `.shellenv.cache`
- Cache invalidation is time-based and event-based

**Environment Scoping**: All plugins follow naming patterns:
- `{PLATFORM}_CONFIG_DIR` - Configuration directory
- `{PLATFORM}_DEVICES_DIR` - Device definitions
- `{PLATFORM}_SCRIPTS_DIR` - Runtime scripts
- `{PLATFORM}_DEFAULT_DEVICE` - Default device selection
- `EVALUATE_DEVICES` - Devices to evaluate (empty = all)

## Common Commands

### Setup
```bash
# Install devbox dependencies
devbox shell

# Validate plugin installation
cd devbox/examples/{android|ios|react-native}
devbox shell
```

### Device Management

#### Android
```bash
# List devices
devbox run --pure android.sh devices list

# Create/update/delete devices
devbox run --pure android.sh devices create pixel_api28 --api 28 --device pixel --tag google_apis
devbox run --pure android.sh devices update pixel_api28 --api 29
devbox run --pure android.sh devices delete pixel_api28

# Select devices for evaluation (reduces CI build time)
devbox run --pure android.sh devices select max
devbox run --pure android.sh devices eval  # Regenerate lock file

# View configuration
devbox run --pure android.sh config show
devbox run --pure android.sh config set ANDROID_DEFAULT_DEVICE=max
```

#### iOS
```bash
# List devices
devbox run --pure ios.sh devices list

# Create/update/delete devices
devbox run --pure ios.sh devices create iphone15 --runtime 17.5
devbox run --pure ios.sh devices update iphone15 --runtime 18.0
devbox run --pure ios.sh devices delete iphone15

# Select devices for evaluation
devbox run --pure ios.sh devices select min max
devbox run --pure ios.sh devices eval  # Regenerate lock file

# View configuration
devbox run --pure ios.sh config show
```

### Building and Running

#### Android
```bash
cd devbox/examples/android

# Build the app
devbox run --pure build-android

# Start emulator
devbox run --pure start-emu [device]  # Defaults to ANDROID_DEFAULT_DEVICE

# Build, install, and launch app on emulator
devbox run --pure start-app [device]

# Stop emulator
devbox run --pure stop-emu
```

#### iOS
```bash
cd devbox/examples/ios

# Build the app
devbox run --pure build-ios

# Start simulator
devbox run --pure start-sim [device]  # Defaults to IOS_DEFAULT_DEVICE

# Build, install, and launch app on simulator
devbox run --pure start-ios [device]

# Stop simulator
devbox run --pure stop-sim
```

#### React Native
```bash
cd devbox/examples/react-native

# Install dependencies
npm install

# Android workflow
devbox run --pure start-emu [device]
devbox run --pure start-app [device]
devbox run --pure stop-emu

# iOS workflow
devbox run --pure start-sim [device]
devbox run --pure start-ios [device]
devbox run --pure stop-sim

# Build for all platforms
devbox run build  # Runs build-android, build-ios, build-web
```

### Testing

#### Plugin Tests
```bash
# Run Android plugin tests
cd devbox/plugins/tests/android
./test-*.sh

# Run iOS plugin tests
cd devbox/plugins/tests/ios
./test-*.sh
```

#### CI Workflows
```bash
# Validate locally with act (requires Docker)
act -j android-plugin-tests
act -j ios-plugin-tests
```

## Project Structure

```
.
├── devbox/
│   ├── plugins/
│   │   ├── android/          # Android plugin
│   │   │   ├── config/       # Default config templates
│   │   │   ├── scripts/      # Runtime scripts (android.sh, avd.sh, etc.)
│   │   │   ├── plugin.json   # Plugin manifest
│   │   │   └── REFERENCE.md  # Complete API reference
│   │   ├── ios/              # iOS plugin
│   │   │   ├── config/
│   │   │   ├── scripts/
│   │   │   ├── plugin.json
│   │   │   └── REFERENCE.md
│   │   ├── react-native/     # React Native plugin
│   │   │   ├── plugin.json
│   │   │   └── REFERENCE.md
│   │   ├── tests/            # Plugin unit tests
│   │   └── CONVENTIONS.md    # Plugin development patterns
│   └── examples/
│       ├── android/          # Minimal Android app
│       │   ├── devbox.d/     # Device definitions and config
│       │   └── devbox.json   # Includes android plugin
│       ├── ios/              # Swift package example
│       │   ├── devbox.d/
│       │   └── devbox.json   # Includes ios plugin
│       └── react-native/     # React Native app
│           ├── devbox.d/     # Both Android and iOS devices
│           └── devbox.json   # Includes react-native plugin
├── .github/workflows/
│   ├── pr-checks.yml         # Fast PR validation (~15-30 min)
│   └── e2e-full.yml          # Full E2E tests (~45-60 min per platform)
└── devbox.json               # Root devbox config
```

## Development Patterns

### Working with Plugins

When modifying plugins:

1. Plugin configuration is in `plugin.json` (init hooks, env vars, scripts)
2. Runtime scripts go in `scripts/` directory
3. Follow conventions in `devbox/plugins/CONVENTIONS.md`:
   - Use `{platform}_` prefixes for functions
   - `set -euo pipefail` for safety
   - Non-blocking validation (warn, don't fail)
   - Debug logging via `{PLATFORM}_DEBUG=1`

### Device Management Workflow

1. Device definitions are JSON files in `devbox.d/{platform}/devices/`
2. Modify devices using CLI commands (not manual editing)
3. After changes, regenerate lock file: `{platform}.sh devices eval`
4. Lock files should be committed to optimize CI

### Adding New Devices

```bash
# Android - specify API level and device profile
devbox run --pure android.sh devices create pixel_api30 \
  --api 30 \
  --device pixel \
  --tag google_apis \
  --preferred_abi x86_64

# iOS - specify simulator runtime version
devbox run --pure ios.sh devices create iphone14 --runtime 16.4

# Regenerate lock file after adding
devbox run --pure {platform}.sh devices eval
```

### Debugging

Enable debug logging:
```bash
# Platform-specific
ANDROID_DEBUG=1 devbox shell
IOS_DEBUG=1 devbox shell

# Global
DEBUG=1 devbox shell
```

Check cache validity:
```bash
# Android - view cached Nix evaluation
cat devbox.d/android/.nix_sdk_eval.cache

# iOS - view cached Xcode path
cat .devbox/virtenv/ios/.xcode_dev_dir.cache
```

Validate lock files:
```bash
devbox run --pure android.sh devices eval
devbox run --pure ios.sh devices eval
```

## CI/CD

### Fast PR Checks (`pr-checks.yml`)
- Runs automatically on every PR
- Plugin validation and quick smoke tests
- ~15-30 minutes total
- Tests default devices only

### Full E2E Tests (`e2e-full.yml`)
- Manual trigger or weekly schedule
- Tests min/max platform versions:
  - Android: API 21 (min) to API 36 (max)
  - iOS: iOS 15.4 (min) to iOS 26.2 (max)
- ~45-60 minutes per platform
- Matrix execution for parallel testing

### Running CI Locally

```bash
# Requires act (GitHub Actions local runner)
# Install: devbox add act

# Run specific jobs
act -j android-plugin-tests
act -j ios-plugin-tests
act -j android-quick-smoke
act -j ios-quick-smoke

# Run full workflow
act -W .github/workflows/pr-checks.yml
```

## Configuration

Configuration for both Android and iOS plugins is now managed via environment variables defined in `plugin.json`. These env vars are converted to JSON at runtime for internal use.

### Android Plugin Environment Variables
- `ANDROID_DEFAULT_DEVICE` - Default emulator
- `ANDROID_APP_APK` - APK path/glob for installation
- `ANDROID_BUILD_TOOLS_VERSION` - Build tools version
- `ANDROID_LOCAL_SDK` - Use local SDK instead of Nix (0/1)
- `EVALUATE_DEVICES` - Devices to evaluate in flake

### iOS Plugin Environment Variables
- `IOS_DEFAULT_DEVICE` - Default simulator
- `IOS_APP_PROJECT` - Xcode project path
- `IOS_APP_SCHEME` - Xcode build scheme
- `IOS_APP_ARTIFACT` - App bundle path/glob
- `IOS_DOWNLOAD_RUNTIME` - Auto-download runtimes (0/1)

## Important Implementation Notes

### Android SDK via Nix Flake
- The Android SDK is composed via Nix flake at `devbox.d/android/flake.nix`
- Flake outputs: `android-sdk`, `android-sdk-full`, `android-sdk-preview`
- SDK evaluation is cached in `.nix_sdk_eval.cache` (1-hour TTL)
- Lock file limits which API versions are evaluated (optimization for CI)

### iOS Xcode Discovery
- Multiple strategies: `IOS_DEVELOPER_DIR` env var → `xcode-select -p` → `/Applications/Xcode*.app`
- Selects latest Xcode by version number
- Path cached in `.xcode_dev_dir.cache` (1-hour TTL)

### Validation Philosophy
- Validation warnings never block execution
- Warn with actionable fix commands
- Skip validation in CI or when tools are missing
- Examples: lock file checksum mismatches, missing SDK paths

### Script Safety
- All scripts use `set -euo pipefail` (or `set -eu` for POSIX)
- Functions return 0 on success, non-zero on failure
- Validation functions use `|| true` to avoid blocking

## References

For complete command and configuration references, see:
- `devbox/plugins/android/REFERENCE.md`
- `devbox/plugins/ios/REFERENCE.md`
- `devbox/plugins/react-native/REFERENCE.md`
- `devbox/plugins/CONVENTIONS.md`
- `.github/workflows/README.md`
