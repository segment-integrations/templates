# Testing Guide

This directory contains orchestrated test suites using process-compose for concurrent execution, health checks, and comprehensive coverage.

## Quick Start

```bash
# Run everything (lint, unit tests, workflow checks, E2E tests)
devbox run test

# Run with interactive TUI to see live progress
TEST_TUI=true devbox run test

# Run specific test suites
devbox run test:unit          # Plugin unit tests
devbox run test:lint          # Linting + workflow validation
devbox run test:e2e           # All E2E tests (sequential)
devbox run test:e2e:android   # Android E2E only
devbox run test:e2e:ios       # iOS E2E only
devbox run test:e2e:rn        # React Native E2E only
```

## Test Architecture

All tests are orchestrated using [process-compose](https://github.com/F1bonacc1/process-compose), providing:

- **Concurrent Execution**: Independent tests run in parallel
- **Dependency Management**: Tests run in correct order automatically
- **Health Checks**: Readiness and liveness probes verify each stage
- **Better Visibility**: Real-time status of all test processes
- **Automatic Retry**: Failed processes can restart
- **Structured Logging**: Per-process logs with configurable verbosity

## Test Suites

### 1. Full Test Suite (`devbox run test`)

**Configuration**: `tests/process-compose-all-tests.yaml`

Runs everything in optimal order:

```
Phase 1 (parallel):
├── lint-android
├── lint-ios
├── lint-react-native
├── lint-tests
└── check-workflows

Phase 2 (parallel, after lint):
├── test-android-lib
├── test-android-devices
└── test-ios-lib

Phase 3 (sequential, after unit tests):
├── e2e-android
├── e2e-ios
└── e2e-react-native
```

**Typical runtime**: ~15-20 minutes (with E2E tests)

### 2. Lint Suite (`devbox run test:lint`)

**Configuration**: `tests/process-compose-lint.yaml`

Runs all static analysis in parallel:

- Shellcheck for Android scripts
- Shellcheck for iOS scripts
- Shellcheck for React Native scripts
- Shellcheck for test scripts
- GitHub workflow syntax validation (via `act`)

**Typical runtime**: ~30 seconds

### 3. Unit Test Suite (`devbox run test:unit`)

**Configuration**: `tests/process-compose-unit-tests.yaml`

Runs plugin unit tests after linting:

**Android tests** (parallel):
- `test-android-lib` - Library function tests
- `test-android-devices` - Device management tests
- `test-android-device-mgmt` - Device CRUD operations
- `test-android-validation` - Validation logic tests

**iOS tests** (parallel):
- `test-ios-lib` - Library function tests
- `test-ios-device-mgmt` - Device CRUD operations
- `test-ios-cache` - Cache invalidation tests

**Typical runtime**: ~2-3 minutes

### 4. E2E Test Suite (`devbox run test:e2e`)

**Configuration**: `tests/process-compose-e2e.yaml`

Runs end-to-end tests sequentially (to avoid resource conflicts):

1. **Android E2E** (`tests/e2e-android-orchestrated.sh`)
   - Setup AVD
   - Build Android app
   - Start emulator (with boot verification)
   - Deploy app
   - Verify app is running
   - Cleanup

2. **iOS E2E** (`tests/e2e-ios-orchestrated.sh`)
   - Verify simulator exists
   - Build iOS app
   - Start simulator (with boot verification)
   - Deploy app
   - Verify app is running
   - Cleanup

3. **React Native E2E** (`tests/e2e-react-native-orchestrated.sh`)
   - Install Node dependencies
   - Build web bundle
   - Run Android workflow
   - Run iOS workflow

**Typical runtime**: ~10-15 minutes

## Individual Test Commands

### Android Tests

```bash
# Run all Android tests
devbox run test:android

# Individual tests
devbox run test:android:lib            # Library functions
devbox run test:android:devices        # Device list/management
devbox run test:android:device-mgmt    # Device CRUD
devbox run test:android:validation     # Validation logic
devbox run lint:android                # Shellcheck only
```

### iOS Tests

```bash
# Run all iOS tests
devbox run test:ios

# Individual tests
devbox run test:ios:lib           # Library functions
devbox run test:ios:device-mgmt   # Device CRUD
devbox run test:ios:cache         # Cache behavior
devbox run lint:ios               # Shellcheck only
```

### React Native Tests

```bash
# Run React Native tests
devbox run test:rn

# Linting only
devbox run lint:rn
```

### E2E Tests

```bash
# All platforms (sequential)
devbox run test:e2e

# Individual platforms
devbox run test:e2e:android   # Android only
devbox run test:e2e:ios       # iOS only
devbox run test:e2e:rn        # React Native (both platforms)

# Legacy tests (non-orchestrated)
devbox run test:e2e:sequential   # Old sequential runner
devbox run test:e2e:parallel     # Old parallel runner (experimental)
```

### Workflow Validation

```bash
# Validate GitHub Actions workflows
devbox run check:workflows
```

## Configuration

### Environment Variables

**Global**:
- `TEST_TUI=true` - Enable interactive TUI mode (default: false)
- `LOG_LEVEL=debug` - Enable verbose logging

**E2E Tests**:
- `TEST_TIMEOUT=300` - Overall test timeout in seconds
- `BOOT_TIMEOUT=180` - Emulator/simulator boot timeout
- `ANDROID_SERIAL=emulator-5554` - Android device serial
- `IOS_DEVICE=max` - iOS simulator name

### Examples

```bash
# Run tests with interactive UI
TEST_TUI=true devbox run test

# Run unit tests only with TUI
TEST_TUI=true devbox run test:unit

# Run Android E2E with extended timeout
TEST_TIMEOUT=600 devbox run test:e2e:android

# Run linting with TUI
TEST_TUI=true devbox run test:lint
```

## Understanding the Output

### Non-TUI Mode (Default)

```
Running orchestrated unit tests...
lint-android: ✓ completed
lint-ios: ✓ completed
test-android-lib: ✓ completed
test-android-devices: ✓ completed
...
```

### TUI Mode (`TEST_TUI=true`)

Interactive dashboard showing:
- Process status (running, completed, failed)
- Real-time logs for each process
- Dependency graph visualization
- Resource usage

**TUI Controls**:
- `h` - Help
- `q` - Quit
- Arrow keys - Navigate processes
- Enter - View process logs

## Logs

Process-compose stores logs in `/tmp/`:

```bash
# View all test logs
ls -la /tmp/devbox-*-logs/

# View specific process log
tail -f /tmp/devbox-unit-tests-logs/test-android-lib.log

# View all logs for a test run
tail -f /tmp/devbox-unit-tests-logs/*.log
```

## Troubleshooting

### Tests Failing Locally

1. **Check logs**:
   ```bash
   ls -la /tmp/devbox-*-logs/
   tail -f /tmp/devbox-all-tests-logs/<process-name>.log
   ```

2. **Run with TUI to see live progress**:
   ```bash
   TEST_TUI=true devbox run test:unit
   ```

3. **Run individual test**:
   ```bash
   devbox run test:android:lib
   ```

### Emulator/Simulator Won't Boot

Increase timeouts:
```bash
BOOT_TIMEOUT=300 TEST_TIMEOUT=600 devbox run test:e2e:android
```

### Workflow Validation Fails

Ensure `act` is working:
```bash
act -l  # Should list workflows
```

If `act` has issues, skip workflow validation:
```bash
# Edit tests/process-compose-lint.yaml
# Comment out the workflow validation processes
```

### Process Stuck

When using TUI mode:
1. Press `q` to quit
2. Check which process is stuck in the log files
3. Kill any orphaned processes:
   ```bash
   # Kill emulators
   devbox run stop:emu

   # Kill simulators
   devbox run stop:sim
   ```

## CI Integration

### GitHub Actions

Use non-TUI mode in CI:

```yaml
- name: Run tests
  run: devbox run test
  # TEST_TUI defaults to false
```

For specific test suites:

```yaml
- name: Lint
  run: devbox run test:lint

- name: Unit tests
  run: devbox run test:unit

- name: E2E tests
  run: devbox run test:e2e:android
```

### Local CI Simulation

Test your CI configuration locally with `act`:

```bash
# List workflows
act -l

# Run PR checks workflow
act -j lint
act -j android-plugin-tests

# Run full workflow
act -W .github/workflows/pr-checks.yml
```

## Performance Tips

### Speed Up Tests

1. **Skip E2E tests during development**:
   ```bash
   devbox run test:unit  # Much faster
   ```

2. **Run platform-specific tests**:
   ```bash
   devbox run test:android  # Only Android unit tests
   ```

3. **Use cached builds**:
   - Don't run `devbox run sync` before every test
   - Gradle/Xcode builds are cached

### Parallel vs Sequential

**Unit tests**: Always parallel (built into orchestration)

**E2E tests**: Sequential by default to avoid:
- Port conflicts
- Resource exhaustion
- Flaky tests

To experiment with parallel E2E (not recommended):
```bash
devbox run test:e2e:parallel  # Legacy parallel runner
```

## Test Development

### Adding New Unit Tests

1. Create test script in `plugins/tests/<platform>/`
2. Add to appropriate process-compose config
3. Update devbox.json with new command

Example:

```yaml
# tests/process-compose-unit-tests.yaml
test-android-new-feature:
  command: "bash plugins/tests/android/test-new-feature.sh"
  depends_on:
    lint-android:
      condition: process_completed_successfully
  availability:
    restart: "no"
```

### Adding New E2E Tests

1. Create orchestrated test script in `tests/`
2. Create process-compose config (see existing examples)
3. Add to `devbox.json` scripts

### Testing Your Test Changes

Always test your test changes:

```bash
# Test the test orchestration
TEST_TUI=true devbox run test:unit

# Verify logs are created
ls -la /tmp/devbox-unit-tests-logs/
```

## Architecture Decisions

### Why Process-Compose?

1. **Better than Make**: Handles long-running processes, health checks, dependencies
2. **Better than shell scripts**: Parallel execution, status monitoring, graceful shutdown
3. **Better than systemd**: Cross-platform, no daemon required, project-local
4. **Better than Docker Compose**: No containerization overhead, native process management

### Why Sequential E2E?

E2E tests are sequential because:
- Emulators/simulators are resource-intensive
- Port conflicts (ADB, iOS device communication)
- More reliable than parallel execution
- Still faster than total runtime (builds are parallelized internally)

### Why Separate Configs?

Different process-compose configs for different test suites because:
- Faster for common cases (unit tests, linting)
- Better error isolation
- Allows different parallelization strategies
- Clearer dependency graphs

## Related Documentation

- [Orchestration README](./README-ORCHESTRATION.md) - Deep dive into process-compose setup
- [Plugin Tests README](../plugins/tests/README.md) - Plugin testing framework
- [Android Plugin Tests](../plugins/tests/android/) - Android-specific tests
- [iOS Plugin Tests](../plugins/tests/ios/) - iOS-specific tests
- [Workflow README](../.github/workflows/README.md) - CI/CD setup

## Summary

```bash
# Quick reference
devbox run test              # Everything
devbox run test:unit         # Unit tests only
devbox run test:lint         # Linting + workflow checks
devbox run test:e2e          # E2E tests only
devbox run test:e2e:android  # Android E2E
devbox run test:e2e:ios      # iOS E2E
devbox run test:e2e:rn       # React Native E2E

# Use TUI for interactive mode
TEST_TUI=true devbox run test:unit

# Check logs
ls -la /tmp/devbox-*-logs/
```
