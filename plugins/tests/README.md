# Plugin Unit Tests

This directory contains **pure unit tests** for plugin scripts. These tests verify individual functions work correctly in isolation.

## Structure

```
plugins/tests/
├── android/
│   ├── test-lib.sh        # Tests for lib.sh utility functions
│   └── test-devices.sh    # Tests for devices.sh CLI parsing
├── ios/
│   └── test-lib.sh        # Tests for lib.sh utility functions
└── test-framework.sh      # Shared test utilities
```

## Running Tests

```bash
# All plugin unit tests
devbox run test:plugin:unit

# Android plugin tests
devbox run test:plugin:android
devbox run test:plugin:android:lib
devbox run test:plugin:android:devices

# iOS plugin tests
devbox run test:plugin:ios
devbox run test:plugin:ios:lib
```

## Test Coverage

### Android (`test-lib.sh`)
- String normalization
- AVD name sanitization
- Device checksum computation
- Path resolution
- Requirement validation

### Android (`test-devices.sh`)
- Device CRUD operations (create, list, show, update, delete)
- Lock file generation
- Device filtering
- JSON file manipulation

### iOS (`test-lib.sh`)
- String normalization
- Path resolution
- Config directory resolution
- Requirement validation

## Test Framework

All tests use `test-framework.sh` utilities:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source test framework
. "path/to/test-framework.sh"

# Write tests
assert_equal "expected" "$(my_function)"
assert_command_success "Test description" my_command arg1 arg2
assert_file_exists "path/to/file"

# Show summary
test_summary
```

## Adding New Tests

1. Create test file in appropriate directory (`plugins/tests/{platform}/`)
2. Use `test-framework.sh` utilities
3. Add command to `devbox.json` if needed
4. Ensure tests run in isolation (no external dependencies)

## Guidelines

- **Pure unit tests only** - Test individual functions directly
- **No integration** - Integration tests are in `/tests/integration/`
- **Fast execution** - All tests should run in under 30 seconds total
- **Isolated** - Tests should not depend on external state or example projects
- **Self-contained** - Create any needed test data inline or in the test file

## Related Testing

- **Integration tests**: `/tests/integration/` - Test plugin workflows with fixtures
- **E2E tests**: `/tests/e2e/` - Test full application lifecycle
- **Test fixtures**: `/tests/fixtures/` - Shared test data for integration tests

See `/tests/README.md` for complete testing guide.
