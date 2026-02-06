# Test Orchestration with Process-Compose

This directory contains orchestrated E2E tests using [process-compose](https://github.com/F1bonacc1/process-compose) for better concurrency, health checks, and lifecycle management.

## Benefits of Process-Compose Orchestration

1. **Automatic Health Checks**: Readiness and liveness probes verify each stage
2. **Dependency Management**: Processes start in the correct order automatically
3. **Parallel Execution**: Independent tasks (build, setup) run concurrently
4. **Status Monitoring**: Real-time view of all test stages
5. **Automatic Retry**: Failed processes can restart with configurable limits
6. **Graceful Shutdown**: Cleanup happens automatically on success or failure
7. **Better Logging**: Structured logs per process with configurable verbosity

## Architecture

### Android Test Flow (`process-compose-android.yaml`)

```
setup-avd (ready probe: AVD exists)
    ↓
android-emulator (ready probe: boot complete, health probe: ADB connection)
    ↓
deploy-app (ready probe: package installed) ← build-app (ready probe: APK exists)
    ↓
verify-app-running (ready probe: process running)
    ↓
cleanup
```

### iOS Test Flow (`process-compose-ios.yaml`)

```
verify-simulator (ready probe: simctl lists device)
    ↓
ios-simulator (ready probe: booted state, health probe: still booted)
    ↓
deploy-app (ready probe: bundle installed) ← build-app (ready probe: .app exists)
    ↓
verify-app-running (ready probe: launchctl shows process)
    ↓
cleanup
```

## Usage

### Run Orchestrated Tests

```bash
# Android with TUI (interactive)
TEST_TUI=true ./tests/e2e-android-orchestrated.sh

# Android without TUI (CI mode)
./tests/e2e-android-orchestrated.sh

# iOS with TUI
TEST_TUI=true ./tests/e2e-ios-orchestrated.sh

# iOS without TUI
./tests/e2e-ios-orchestrated.sh
```

### Direct Process-Compose Invocation

```bash
# Run with interactive TUI
cd examples/android
process-compose -f ../../tests/process-compose-android.yaml --tui

# Run in CI mode (no TUI)
cd examples/android
process-compose -f ../../tests/process-compose-android.yaml --tui=false

# See logs
tail -f /tmp/android-e2e-logs/*
```

## Configuration

### Environment Variables

**Android:**
- `ANDROID_SERIAL` - Emulator serial (default: `emulator-5554`)
- `ANDROID_APP_ID` - Package name for verification
- `ANDROID_DEFAULT_DEVICE` - Device to test
- `TEST_TIMEOUT` - Overall timeout (default: 300s)
- `BOOT_TIMEOUT` - Emulator boot timeout (default: 180s)
- `TEST_TUI` - Enable TUI mode (default: false)

**iOS:**
- `IOS_DEVICE` - Simulator name
- `IOS_APP_BUNDLE_ID` - Bundle ID for verification
- `TEST_TIMEOUT` - Overall timeout (default: 300s)
- `BOOT_TIMEOUT` - Simulator boot timeout (default: 120s)
- `TEST_TUI` - Enable TUI mode (default: false)

### Timeouts

Each process has configurable timeouts in the YAML:

- `readiness_probe.timeout_seconds` - How long to wait for readiness
- `readiness_probe.period_seconds` - How often to check
- `liveness_probe.timeout_seconds` - Health check timeout
- `shutdown.timeout_seconds` - Graceful shutdown timeout

Example customization:

```yaml
processes:
  android-emulator:
    readiness_probe:
      timeout_seconds: 300  # Increase for slow boot
      period_seconds: 5      # Check less frequently
```

## Probes Explained

### Readiness Probe
Checks if a process has successfully started and is ready for the next stage.

**Example**: Wait for emulator boot to complete
```yaml
readiness_probe:
  exec:
    command: "adb shell getprop sys.boot_completed | grep -q 1"
  initial_delay_seconds: 10  # Wait 10s before first check
  period_seconds: 3           # Check every 3s
  timeout_seconds: 180        # Fail after 180s
  success_threshold: 1        # Need 1 success to be ready
```

### Liveness Probe
Continuously checks if a running process is still healthy.

**Example**: Ensure emulator stays connected
```yaml
liveness_probe:
  exec:
    command: "adb devices | grep -q emulator-5554"
  initial_delay_seconds: 15   # Start checking after 15s
  period_seconds: 10          # Check every 10s
  failure_threshold: 3        # Fail after 3 consecutive failures
```

## Process Dependencies

Use `depends_on` to control execution order:

```yaml
deploy-app:
  depends_on:
    build-app:
      condition: process_completed_successfully  # Must finish successfully
    android-emulator:
      condition: process_healthy  # Must be running and healthy
```

**Dependency Conditions:**
- `process_completed` - Dependency finished (any exit code)
- `process_completed_successfully` - Dependency finished with exit code 0
- `process_healthy` - Dependency passed readiness probe and is running

## Parallel Execution

Processes without dependencies run in parallel automatically:

```yaml
# These run concurrently:
setup-avd:    # No dependencies
  command: "..."

build-app:    # No dependencies
  command: "..."
```

## Troubleshooting

### Check Process Status

```bash
# While running with TUI
# Press 'h' for help, 'q' to quit

# View logs
ls -la /tmp/android-e2e-logs/
tail -f /tmp/android-e2e-logs/android-emulator.log
```

### Common Issues

**Emulator won't boot:**
- Increase `readiness_probe.timeout_seconds` in emulator process
- Check `/tmp/android-e2e-logs/android-emulator.log`

**Build timeout:**
- Increase `readiness_probe.timeout_seconds` in build-app process
- Check disk space and clean Gradle cache

**App not deploying:**
- Verify `ANDROID_APP_APK` or `IOS_APP_ARTIFACT` paths are correct
- Check `deploy-app.log` for errors

### Debug Mode

Enable verbose logging:

```yaml
log_level: debug  # Change from 'info' to 'debug'
```

## CI Integration

For CI environments, use non-interactive mode:

```bash
# .github/workflows/e2e.yml
- name: Run Android E2E
  run: |
    cd examples/android
    process-compose -f ../../tests/process-compose-android.yaml \
      --tui=false \
      --ordered-shutdown
```

## Extending Tests

### Add New Verification Step

```yaml
verify-custom-check:
  command: "your-verification-command"
  depends_on:
    deploy-app:
      condition: process_completed_successfully
  availability:
    restart: "no"
  readiness_probe:
    exec:
      command: "your-check-command"
    timeout_seconds: 30
```

### Add Cleanup Logic

```yaml
cleanup:
  command: |
    adb shell pm clear com.example.app
    devbox run stop:emu
  depends_on:
    verify-app-running:
      condition: process_completed  # Runs even if tests fail
  availability:
    restart: "no"
```

## Comparison: Old vs Orchestrated

### Old Approach
```bash
# Sequential, no verification
devbox run start:android  # Blocks, no status checks
# Hope it worked...
devbox run stop:emu
```

**Problems:**
- No visibility into what's happening
- Can't tell if emulator actually booted
- No verification app is running
- Can't run builds in parallel
- Hard to debug failures

### Orchestrated Approach
```bash
process-compose -f tests/process-compose-android.yaml
```

**Benefits:**
- Real-time status of all stages
- Automatic health checks at each step
- Parallel build + setup
- Detailed verification of app state
- Structured logs per component
- Automatic cleanup on failure
- Can retry failed stages
- Works identically in CI and locally

## Performance

**Typical execution time improvements:**

| Test Stage | Old (Sequential) | Orchestrated (Parallel) |
|------------|------------------|-------------------------|
| Setup AVD + Build | 60s + 120s = 180s | max(60s, 120s) = 120s |
| Total Android E2E | ~5 minutes | ~3.5 minutes |
| Total iOS E2E | ~4 minutes | ~3 minutes |

**Why faster:**
- Setup and build run in parallel
- No unnecessary waiting between stages
- Faster failure detection
- Efficient readiness checking
