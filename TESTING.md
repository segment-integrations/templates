# Testing Guide

This repository includes comprehensive **orchestrated testing** using process-compose for all mobile plugins and example projects.

## Quick Start

```bash
# Run EVERYTHING (lint, unit, integration, E2E tests)
devbox run test

# Run with interactive TUI to see live progress
TEST_TUI=true devbox run test

# Run specific test suites
devbox run test:fast         # Fast tests (lint + unit + integration) ⚡
devbox run test:e2e          # E2E tests only (slow)

# Sync examples with latest plugins
devbox run sync
```

## What's New: Orchestrated Testing 🚀

All tests are now orchestrated using [process-compose](https://github.com/F1bonacc1/process-compose), providing:

- ✅ **Automatic Status Checks** - Health probes verify each stage (emulator boot, app installed, etc.)
- ✅ **Concurrent Execution** - Independent tests run in parallel automatically
- ✅ **Configurable Timeouts** - Every step has timeout + polling for completion
- ✅ **Better Visibility** - Real-time status of all test processes
- ✅ **Dependency Management** - Tests run in correct order
- ✅ **Automatic Cleanup** - Graceful shutdown even on failure
- ✅ **Structured Logging** - Per-process logs with configurable verbosity

## Available Commands

### Master Test Suite

| Command | Description |
|---------|-------------|
| `devbox run test` | **Everything** (lint, unit, workflow checks, E2E) |
| `TEST_TUI=true devbox run test` | Run with interactive dashboard |

### Test Suites

| Command | Description | What It Does |
|---------|-------------|--------------|
| `devbox run test:fast` | Fast tests | Lint + unit + integration (1-2 min) ⚡ |
| `devbox run test:lint` | Linting + validation | Shellcheck all scripts, validate GitHub workflows |
| `devbox run test:plugin:unit` | Plugin unit tests | All Android, iOS unit tests (parallel) |
| `devbox run test:integration` | Integration tests | Plugin workflows with fixtures |
| `devbox run test:e2e` | E2E tests | Full workflow tests (10-15 min) |

### Platform-Specific Tests

| Command | Description |
|---------|-------------|
| `devbox run test:android` | Android plugin tests |
| `devbox run test:ios` | iOS plugin tests |
| `devbox run test:rn` | React Native plugin tests |
| `devbox run test:e2e:android` | Android E2E only |
| `devbox run test:e2e:ios` | iOS E2E only |
| `devbox run test:e2e:rn` | React Native E2E only |

### Individual Test Commands

| Command | Description |
|---------|-------------|
| `devbox run test:plugin:android:lib` | Android library functions |
| `devbox run test:plugin:android:devices` | Android device management |
| `devbox run test:integration:android:device-mgmt` | Android device integration |
| `devbox run test:integration:android:validation` | Android validation logic |
| `devbox run test:plugin:ios:lib` | iOS library functions |
| `devbox run test:integration:ios:device-mgmt` | iOS device integration |
| `devbox run test:integration:ios:cache` | iOS cache behavior |
| `devbox run lint:android` | Lint Android only |
| `devbox run lint:ios` | Lint iOS only |
| `devbox run lint:rn` | Lint React Native only |

### Other Commands

| Command | Description |
|---------|-------------|
| `devbox run sync` | Sync example projects with latest plugins |
| `devbox run check:workflows` | Validate GitHub Actions syntax |

## Interactive TUI Mode

Enable the process-compose TUI for real-time monitoring:

```bash
# See live status of all tests
TEST_TUI=true devbox run test

# TUI for specific suites
TEST_TUI=true devbox run test:unit
TEST_TUI=true devbox run test:lint
TEST_TUI=true devbox run test:e2e
```

**TUI Controls:**
- `h` - Help
- `q` - Quit
- Arrow keys - Navigate processes
- Enter - View process logs

## How Orchestrated Tests Work

### Lint Suite (`test:lint`)

Runs **in parallel**:
```
lint-android-scripts
lint-ios-scripts
lint-react-native-scripts
lint-test-scripts
validate-pr-checks-workflow
validate-e2e-full-workflow
```

### Unit Test Suite (`test:unit`)

**Phase 1 (parallel):** Lint all platforms
**Phase 2 (parallel):** Run all unit tests
```
Android Tests          iOS Tests
├─ test-android-lib    ├─ test-ios-lib
├─ test-android-devices├─ test-ios-device-mgmt
├─ test-android-device-└─ test-ios-cache
└─ test-android-validation
```

### E2E Test Suite (`test:e2e`)

**Orchestrated execution** (platforms run one at a time to avoid resource conflicts, but with internal parallelization):
```
1. Android E2E
   ├─ Setup AVD & Build app (concurrent)
   ├─ Start emulator → wait for boot complete ✓
   ├─ Deploy app → verify installed ✓
   └─ Verify app running ✓

2. iOS E2E (after Android completes)
   ├─ Verify simulator & Build app (concurrent)
   ├─ Start simulator → wait for boot complete ✓
   ├─ Deploy app → verify installed ✓
   └─ Verify app running ✓

3. React Native E2E (after iOS completes)
   ├─ Install deps & build web (concurrent)
   ├─ Android workflow
   └─ iOS workflow
```

### Master Test Suite (`test`)

**Runs everything with orchestrated dependencies:**
```
Phase 1: Lint + Workflow Checks (concurrent)
    ↓
Phase 2: Unit Tests (concurrent)
    ↓
Phase 3: E2E Tests (orchestrated, one platform at a time)
    ↓
Summary Report
```

## Status Checks & Timeouts

Every stage has **automatic verification**:

**Emulator Boot:**
- Polls `adb shell getprop sys.boot_completed` every 3s
- Timeout: 180s (configurable via `BOOT_TIMEOUT`)

**App Installation:**
- Polls `adb shell pm list packages` every 3s
- Timeout: 60s

**App Running:**
- Polls `adb shell pidof <package>` every 3s
- Timeout: 30s

**Simulator Boot:**
- Polls `xcrun simctl list` for "(Booted)" every 3s
- Timeout: 120s (configurable via `BOOT_TIMEOUT`)

Configure timeouts:
```bash
BOOT_TIMEOUT=300 TEST_TIMEOUT=600 devbox run test:e2e:android
```

## Viewing Logs

Process-compose stores logs in `/tmp/`:

```bash
# View all test logs
ls -la /tmp/devbox-*-logs/

# View specific process log
tail -f /tmp/devbox-unit-tests-logs/test-android-lib.log

# View all logs for a test run
tail -f /tmp/devbox-all-tests-logs/*.log
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TEST_TUI` | Enable interactive TUI | `false` |
| `TEST_TIMEOUT` | Overall test timeout (seconds) | `300` |
| `BOOT_TIMEOUT` | Emulator/simulator boot timeout | `180` |
| `ANDROID_SERIAL` | Android device serial | `emulator-5554` |
| `IOS_DEVICE` | iOS simulator name | `max` |

### Examples

```bash
# Run with TUI and extended timeouts
TEST_TUI=true BOOT_TIMEOUT=300 devbox run test:e2e:android

# Run unit tests with verbose logging
TEST_TUI=true devbox run test:unit

# Run everything with TUI
TEST_TUI=true devbox run test
```


## CI Integration

CI uses non-TUI mode automatically:

```yaml
# .github/workflows/pr-checks.yml
- name: Run tests
  run: devbox run test  # TEST_TUI defaults to false
```

Test locally with `act`:

```bash
# Simulate CI environment
act -j lint
act -j android-plugin-tests
act -W .github/workflows/pr-checks.yml
```

## Troubleshooting

### View Process Status

```bash
# Run with TUI to see what's happening
TEST_TUI=true devbox run test:unit

# Check logs
ls -la /tmp/devbox-*-logs/
tail -f /tmp/devbox-all-tests-logs/<process-name>.log
```

### Increase Timeouts

```bash
# Emulator taking too long to boot
BOOT_TIMEOUT=300 devbox run test:e2e:android

# Overall test timeout
TEST_TIMEOUT=600 devbox run test:e2e
```

### Kill Stuck Processes

```bash
# Stop emulators
devbox run stop:emu

# Stop simulators
devbox run stop:sim
```

## More Information

- [tests/README.md](tests/README.md) - Complete testing guide
- [tests/README-ORCHESTRATION.md](tests/README-ORCHESTRATION.md) - Deep dive into orchestration
- [plugins/tests/README.md](plugins/tests/README.md) - Plugin testing framework

## Summary

```bash
# Quick reference
devbox run test              # Everything (lint, unit, integration, E2E)
devbox run test:fast         # Fast tests (lint + unit + integration) ⚡
devbox run test:e2e          # E2E tests only

# Use TUI for live progress
TEST_TUI=true devbox run test

# Platform-specific
devbox run test:android      # Android: lint + unit + integration
devbox run test:ios          # iOS: lint + unit + integration
devbox run test:e2e:android  # Android E2E
devbox run test:e2e:ios      # iOS E2E

# Check logs
ls -la /tmp/devbox-*-logs/
```
