# Plugin Tests

This directory contains unit tests and E2E tests for the Devbox mobile plugins.

## Test Structure

```
tests/
├── test-framework.sh       # Shared test utilities and assertions
├── e2e-all.sh             # Parallel E2E test runner for all examples
├── android/               # Android plugin tests
│   ├── test-lib.sh        # lib.sh function tests
│   ├── test-devices.sh    # devices.sh CLI tests
│   ├── test-device-mgmt.sh # Device management E2E tests
│   └── test-validation.sh # Validation function tests
└── ios/                   # iOS plugin tests
    ├── test-lib.sh        # lib.sh function tests
    ├── test-device-mgmt.sh # Device management E2E tests
    └── test-cache.sh      # Cache mechanism tests
```

## Running Tests

### Quick Reference

```bash
# Unit tests
devbox run test                  # All plugin tests (lint + unit)
devbox run test:unit             # All unit tests only
devbox run test:android          # Android plugin tests
devbox run test:ios              # iOS plugin tests
devbox run test:rn               # React Native plugin tests

# E2E tests
devbox run test:e2e              # All E2E tests (parallel, recommended)
devbox run test:e2e:sequential   # All E2E tests (sequential)
devbox run test:e2e:android      # Android example E2E
devbox run test:e2e:ios          # iOS example E2E
devbox run test:e2e:rn           # React Native example E2E

# Linting
devbox run lint                  # Lint all plugins
devbox run lint:android          # Lint Android only
devbox run lint:ios              # Lint iOS only
devbox run lint:rn               # Lint React Native only

# Other
devbox run sync                  # Sync example projects
devbox run check:workflows       # Validate GitHub Actions
```

### Unit Tests

Run unit tests for individual plugins:

```bash
# All plugins
devbox run test

# Individual plugins
devbox run test:android
devbox run test:ios
devbox run test:rn

# Specific test suites
devbox run test:android:lib
devbox run test:android:devices
devbox run test:ios:lib
```

### E2E Tests

E2E tests build and deploy example apps to emulators/simulators.

#### Sequential E2E Tests (Default)

The `test:e2e` command runs E2E tests sequentially with live output:

```bash
devbox run test:e2e
```

**Execution Strategy:**
- Tests run one at a time
- Android → iOS → React Native
- All output visible in real-time

**Benefits:**
- See exactly what's happening as it runs
- Easy to debug failures
- No need to wait for completion to see errors
- Clear progress through each step

**When to use:**
- Development and debugging (most common)
- When you want to watch progress
- When troubleshooting issues

#### Parallel E2E Tests (Faster)

For faster execution, run tests in parallel:

```bash
devbox run test:e2e:parallel
```

**Execution Strategy:**
- **Phase 1**: Android and iOS tests run concurrently (in parallel)
  - Each platform's tests run sequentially to avoid emulator/simulator conflicts
  - Maximum efficiency with no resource contention
- **Phase 2**: React Native tests run after Phase 1 completes
  - Tests both Android and iOS sequentially
  - Only runs if Phase 1 passes

**Benefits:**
- ~50% faster than sequential execution
- Safe: no emulator/simulator conflicts
- Clear output with color-coded logs
- Individual test results and final summary

**When to use:**
- CI/CD pipelines
- Quick validation
- When you don't need live feedback

#### Individual Example E2E Tests

Test a single example in isolation:

```bash
# Android only
devbox run test:e2e:android

# iOS only
devbox run test:e2e:ios

# React Native only (tests both platforms)
devbox run test:e2e:rn
```

## E2E Test Coverage

Each E2E test performs the following steps:

### Android Example
1. Build Android app with Gradle
2. Start Android emulator
3. Deploy app to emulator and verify launch
4. Stop emulator

### iOS Example
1. Build iOS app with xcodebuild
2. Start iOS simulator
3. Deploy app to simulator and verify launch
4. Stop simulator

### React Native Example
1. Install Node dependencies
2. Build web bundle with Metro
3. Build Android app
4. Start Android emulator and deploy app
5. Stop Android emulator
6. Build iOS app
7. Start iOS simulator and deploy app
8. Stop iOS simulator

## Test Output

### Unit Tests
Unit tests use the `test-framework.sh` utilities for consistent output:
- `✓` for passed tests
- `✗` for failed tests
- Summary with pass/fail counts

### E2E Tests
E2E tests provide detailed step-by-step output:
- Color-coded logs for each platform
- Real-time progress indicators
- Clear error messages on failure
- Automatic cleanup on success or failure

**Parallel E2E Output Example:**
```
=========================================
Phase 1: Running Android and iOS Tests Concurrently
=========================================

Starting Android test in background...
Starting iOS test in background...

Waiting for Android and iOS tests to complete...

=========================================
Phase 1 Results
=========================================

Android test output:
[ANDROID] 1/4 Building Android app...
[ANDROID] 2/4 Starting Android emulator...
[ANDROID] 3/4 Deploying app to emulator...
[ANDROID] 4/4 Stopping emulator...
[ANDROID] ✓ Android example E2E test passed!

iOS test output:
[iOS] 1/4 Building iOS app...
[iOS] 2/4 Starting iOS simulator...
[iOS] 3/4 Deploying app to simulator...
[iOS] 4/4 Stopping simulator...
[iOS] ✓ iOS example E2E test passed!

✓ Android Example: PASSED
✓ iOS Example: PASSED
```

## Debugging Failed Tests

When tests fail, check:

1. **Log files**: E2E tests write to `/tmp/e2e-*-<pid>.log`
2. **Emulator/simulator state**: Ensure no stale instances are running
3. **Build artifacts**: Check if previous builds are corrupted
4. **Environment**: Verify Xcode and Android SDK are properly configured

### Common Issues

**Android emulator fails to start:**
- Check `ANDROID_SDK_ROOT` is set correctly
- Verify system images are installed
- Ensure no emulator is already running

**iOS simulator fails to start:**
- Verify Xcode Command Line Tools are installed
- Check `xcode-select -p` points to valid Xcode
- Ensure CoreSimulatorService is healthy

**React Native build failures:**
- Run `npm install` in the example directory
- Clear Metro bundler cache: `rm -rf /tmp/metro-*`
- Check node version compatibility

## CI/CD Integration

The parallel E2E test runner (`e2e-all.sh`) is designed for CI environments:
- Non-zero exit code on any test failure
- Structured output for parsing
- Automatic cleanup of temporary files
- Parallel execution maximizes CI efficiency

**GitHub Actions Example:**
```yaml
# For CI, use parallel for speed
- name: Run E2E Tests
  run: devbox run test:e2e:parallel

# For debugging CI issues, use sequential
- name: Run E2E Tests (debug)
  run: devbox run test:e2e
```

## Writing New Tests

### Unit Tests

Use the test framework utilities:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source test framework
. "path/to/test-framework.sh"

# Test something
assert_command_success "My test" "my-command arg1 arg2"
assert_equal "expected" "$(my-function)"
assert_file_exists "path/to/file"

# Show summary
test_summary
```

### E2E Tests

Follow the pattern in `e2e-all.sh`:
1. Run steps sequentially within a platform
2. Capture output to log file
3. Return non-zero on failure
4. Always attempt cleanup (emulator/simulator stop)

## Performance

Typical execution times on Apple Silicon Mac:

- **Unit tests**: ~10-30 seconds
- **Sequential E2E tests**: ~10-15 minutes
- **Parallel E2E tests**: ~6-8 minutes (40-50% faster)

*Times vary based on build caching and simulator startup performance*
