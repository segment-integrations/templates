# Android Plugin Tests

This directory contains tests for the Android devbox plugin. These tests are automatically available when you include the Android plugin in your project.

## Test Types

### Unit Tests

Test individual bash functions and plugin logic:

```bash
devbox run test:unit
```

**Tests:**
- `test-lib.sh` - Library functions (normalization, checksums, path resolution)
- `test-devices.sh` - Device management (CRUD operations, lock files)

### E2E Tests

Complete end-to-end workflow test:

```bash
devbox run test:e2e
```

**Steps:**
1. Build Android app (`$ANDROID_APP_APK`)
2. Sync AVDs with device definitions
3. Start Android emulator
4. Deploy app to emulator
5. Verify app is running
6. Cleanup

### All Tests

Run both unit and E2E tests:

```bash
devbox run test
```

## Configuration

The E2E test uses these environment variables (configurable in your `devbox.json`):

```json
{
  "env": {
    "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk",
    "ANDROID_APP_ID": "com.example.myapp",
    "ANDROID_SERIAL": "emulator-5554",
    "ANDROID_DEFAULT_DEVICE": "max"
  }
}
```

## Interactive Mode

Run tests with TUI for debugging:

```bash
TEST_TUI=true devbox run test:e2e
```

## Test Files

The plugin automatically copies test files to `.devbox/virtenv/android/`:

- `tests/test-lib.sh` - Unit tests for lib.sh functions
- `tests/test-devices.sh` - Device management tests
- `test-suite.yaml` - E2E test orchestration
- `test-summary.sh` - Test result formatting

## Writing Your Own Tests

See `examples/android/tests/` for examples of project-specific tests you can copy into your own projects.
