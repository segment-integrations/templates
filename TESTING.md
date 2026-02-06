# Testing Guide

This document describes the testing infrastructure for the mobile development plugins and example projects.

## Quick Start

```bash
# Sync all example projects with latest plugin code
devbox run sync-examples

# Run all unit tests and linting
devbox run test-all

# Run E2E tests for all example projects (requires emulators/simulators)
devbox run test-examples-e2e
```

## Syncing Examples with Plugins

After making changes to plugin code, run `sync-examples` to regenerate all example projects:

```bash
devbox run sync-examples
```

This script:
1. Removes `devbox.d`, `devbox.lock`, and `.devbox` from each example
2. Runs `devbox install` to regenerate from latest plugin code
3. Regenerates device lockfiles for reproducibility
4. Verifies React Native env-based overrides are applied (API 35)

**When to run:** After any plugin changes, before running E2E tests, or before committing plugin updates.

## Test Categories

### 1. Unit Tests & Linting

Fast tests that don't require emulators or simulators.

```bash
# Lint all plugin scripts
devbox run lint-all

# Android plugin tests
devbox run test-android           # All Android tests
devbox run test-android-lib       # lib.sh function tests
devbox run test-android-devices   # devices.sh CLI tests

# iOS plugin tests
devbox run test-ios               # All iOS tests
devbox run test-ios-lib           # lib.sh function tests

# React Native plugin tests
devbox run test-react-native      # Lint checks

# GitHub Actions workflow validation
devbox run check-workflows
```

### 2. E2E (End-to-End) Tests

Full integration tests that build apps and deploy to emulators/simulators. These tests run **sequentially** to avoid conflicts.

#### Prerequisites

- **Android E2E**: Requires Android SDK and emulator images
- **iOS E2E**: Requires macOS with Xcode and simulator runtimes
- **Time**: Allow 10-30 minutes per platform depending on hardware

#### Running E2E Tests

```bash
# Run all E2E tests (Android + iOS + React Native)
devbox run test-examples-e2e

# Run individual platform tests
devbox run test-android-example-e2e
devbox run test-ios-example-e2e
devbox run test-react-native-example-e2e
```

#### What Each E2E Test Does

**Android Example (`test-android-example-e2e`):**
1. Build the Android app
2. Start the Android emulator
3. Deploy and launch the app
4. Stop the emulator

**iOS Example (`test-ios-example-e2e`):**
1. Build the iOS app
2. Start the iOS simulator
3. Deploy and launch the app
4. Stop the simulator

**React Native Example (`test-react-native-example-e2e`):**
1. Install Node dependencies
2. Build web bundle
3. Build Android app
4. Start Android emulator and deploy
5. Stop Android emulator
6. Build iOS app
7. Start iOS simulator and deploy
8. Stop iOS simulator

## CI/CD Integration

### Pull Request Checks

Fast validation that runs on every PR:

```yaml
# .github/workflows/pr-checks.yml
- devbox run lint-all
- devbox run test-android
- devbox run test-ios
- devbox run test-react-native
- devbox run check-workflows
```

**Duration**: ~5-10 minutes

### Full E2E Tests

Comprehensive tests run weekly or manually:

```yaml
# .github/workflows/e2e-full.yml
- devbox run test-examples-e2e
```

**Duration**: ~30-60 minutes (platform-dependent)

## Test Output

All tests provide clear progress indicators and summaries:

```
=========================================
Running all tests and checks...
=========================================

1/6 Linting all plugin scripts...
✓ All scripts passed shellcheck

2/6 Testing Android plugin...
✓ 15/15 tests passed

...

=========================================
✓ All tests passed!
=========================================

Summary:
  - Shellcheck: all plugin scripts
  - Android: lib.sh + devices.sh tests
  - iOS: lib.sh tests
  - React Native: lint checks
  - GitHub Actions: workflow syntax validation

Note: Run "devbox run test-examples-e2e" for full E2E tests
```

## Writing New Tests

### Plugin Unit Tests

Add tests to `devbox/plugins/tests/{platform}/test-*.sh`:

```bash
#!/usr/bin/env bash
set -e

echo "TEST: my_function - description"
result=$(my_function "input")
if [ "$result" = "expected" ]; then
  echo "  ✓ PASS"
else
  echo "  ✗ FAIL: Expected 'expected', got '$result'"
  exit 1
fi
```

### E2E Tests

E2E tests are defined in the root `devbox.json` under `shell.scripts`. They should:

1. Change to the example directory: `cd devbox/examples/{platform}`
2. Use `devbox run --pure` to ensure clean environment
3. Follow the pattern: build → start emulator → deploy → stop emulator
4. Print clear progress messages

## Troubleshooting

### E2E Tests Fail to Start Emulator

- **Android**: Check that emulator images are installed: `devbox run android.sh devices list`
- **iOS**: Verify simulator runtimes: `devbox run ios.sh devices list`
- Check disk space (emulators require 5-10GB)

### Tests Timeout

- Increase timeout in CI workflow or run locally
- Check that virtualization is enabled (Android requires KVM on Linux)

### Emulator Already Running

E2E tests stop emulators before exiting, but if a test fails mid-run:

```bash
# Android
devbox run --pure stop-emu

# iOS
devbox run --pure stop-sim
```

## Coverage

Current test coverage:

- ✅ **Plugin Scripts**: 100% linted with shellcheck
- ✅ **Android Plugin**: lib.sh functions, devices CLI
- ✅ **iOS Plugin**: lib.sh functions
- ✅ **React Native Plugin**: Script linting
- ✅ **E2E**: Full build and deployment cycle for all platforms
- ✅ **GitHub Actions**: Workflow syntax validation

Future additions:
- Integration tests for Nix flake evaluation
- Performance benchmarks
- Cross-platform compatibility matrix tests
