# Plugin Configuration Conventions

## Environment Variable Naming

All plugins follow these patterns:

### Directory Paths
- `{PLATFORM}_CONFIG_DIR` - Project configuration directory (`devbox.d/{platform}`)
- `{PLATFORM}_DEVICES_DIR` - Device definitions directory
- `{PLATFORM}_SCRIPTS_DIR` - Runtime scripts directory (`.devbox/virtenv/{platform}/scripts`)

### Platform-Specific Configuration
- `{PLATFORM}_DEFAULT_DEVICE` - Default device name when none specified
- `EVALUATE_DEVICES` - Array of device names to evaluate (empty = all)

### Build/App Configuration
- `{PLATFORM}_APP_*` - Application-specific paths (APK, bundle, derived data, etc.)

## File Naming Conventions

- `plugin.json` - Plugin manifest
- `README.md` - User-facing plugin overview
- `REFERENCE.md` - Complete API reference
- `{platform}.json` - Platform configuration defaults
- `devices.lock.json` - Generated lock file (optimization for CI)
- `process-compose.yaml` - Service definitions

## Script Conventions

- All scripts use `set -euo pipefail` for safety (or `set -eu` for POSIX compatibility)
- Functions prefixed with platform namespace (`android_`, `ios_`)
- Debug logging controlled by `{PLATFORM}_DEBUG=1` or `DEBUG=1`
- Validation functions warn but never block (non-zero exit with `|| true`)

## Device Management Patterns

### Device Definitions
Device definitions are stored as JSON files in `devbox.d/{platform}/devices/`:

**Android**: `device_name.json`
```json
{
  "name": "pixel",
  "api": 28,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

**iOS**: `device_name.json`
```json
{
  "name": "iphone15",
  "runtime": "17.5"
}
```

### Lock Files

Lock files are generated from device definitions to optimize CI builds:

**Purpose**: CI optimization - only evaluate/download SDK for selected device APIs instead of all devices

**Android**: `devices.lock.json`
```json
{
  "api_versions": [28, 35, 36],
  "checksum": "abc123..."
}
```

**iOS**: `devices.lock.json`
```json
{
  "devices": ["min", "max"],
  "checksum": "def456...",
  "generated_at": "2026-02-02T12:00:00Z"
}
```

**Generation**: Run `devbox run {platform}.sh devices eval` to regenerate lock file

## Caching Strategy

### Performance Optimizations
All plugins implement TTL-based caching (1 hour) for expensive operations:

- **Xcode Discovery** (iOS): Cache location of Xcode developer directory
- **Nix SDK Evaluation** (Android): Cache Nix flake evaluation results
- **DevBox ShellEnv** (iOS): Cache devbox shellenv output

### Cache Invalidation
- Time-based: 1 hour TTL for all caches
- Event-based: Android Nix cache invalidates when `devices.lock.json` changes
- Location: Cache files stored in `.devbox/virtenv/{platform}/` (git-ignored)

### Cache Files
- `.xcode_dev_dir.cache` - Xcode developer directory path
- `.nix_sdk_eval.cache` - Nix SDK evaluation output
- `.shellenv.cache` - DevBox shellenv export commands

## Validation Patterns

### Non-Blocking Validation
All validation functions follow these principles:

- **Warn, don't block**: Validation warnings never prevent execution
- **Actionable messages**: Include command to fix the issue
- **Environment-aware**: Skip validation when appropriate (e.g., CI, missing tools)

### Validation Functions
- `{platform}_validate_lock_file()` - Check if lock file matches device definitions
- `{platform}_validate_sdk()` / `{platform}_validate_xcode()` - Verify toolchain availability
- `{platform}_validate_*()` - Additional platform-specific checks

### Checksum Validation
Lock files include SHA-256 checksums of device definition files:

```bash
# Compute checksum (cross-platform)
if command -v sha256sum >/dev/null 2>&1; then
  checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; | sha256sum | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
  checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; | shasum -a 256 | cut -d' ' -f1)
fi
```

## Command Patterns

### Platform CLI Structure
Each platform provides a unified CLI: `{platform}.sh <command> [args]`

**Common Commands**:
- `devices list` - List available device definitions
- `devices create <name> [options]` - Create new device definition
- `devices select <name>` - Select device(s) for evaluation
- `devices eval` - Regenerate lock file from selected devices
- `config show` - Display platform configuration
- `config set KEY=VALUE` - Update configuration values
- `config reset` - Reset to default configuration
- `info` - Display resolved SDK/toolchain information

### Device Management Commands

**Android-specific**:
```bash
android.sh devices create pixel_api28 --api 28 --device pixel --tag google_apis
android.sh devices update pixel_api28 --api 29
android.sh devices delete pixel_api28
```

**iOS-specific**:
```bash
ios.sh devices create iphone15 --runtime 17.5
ios.sh devices update iphone15 --runtime 18.0
ios.sh devices delete iphone15
```

## Platform-Specific Patterns

### Android

**SDK Management**:
- Uses Nix flake for reproducible SDK composition
- Flake located at `devbox.d/android/flake.nix`
- SDK configured based on API versions in lock file
- Supports local SDK override with `ANDROID_LOCAL_SDK=1`

**Key Variables**:
- `ANDROID_SDK_ROOT` - SDK installation path
- `ANDROID_HOME` - Alias for SDK root (compatibility)
- `ANDROID_SDK_FLAKE_OUTPUT` - Nix flake output name
- `ANDROID_BUILD_TOOLS_VERSION` - Build tools version
- `ANDROID_SYSTEM_IMAGE_TAG` - System image type (google_apis, etc.)

### iOS

**Toolchain Management**:
- Relies on system Xcode installation
- Discovers Xcode via multiple strategies (IOS_DEVELOPER_DIR, xcode-select, /Applications)
- Version selection: Latest Xcode by version number

**Key Variables**:
- `DEVELOPER_DIR` - Xcode developer directory path
- `IOS_DEFAULT_RUNTIME` - iOS simulator runtime version
- `IOS_APP_PROJECT` - Xcode project path
- `IOS_APP_SCHEME` - Xcode build scheme
- `IOS_DOWNLOAD_RUNTIME` - Auto-download missing runtimes (0/1)

## Testing Conventions

### Test Organization
- Test framework: Shell scripts with assertion helpers
- Location: `devbox/plugins/tests/{platform}/`
- Test files: `test-*.sh`
- CI workflows: `.github/workflows/{platform}-plugin-tests.yml`

### Test Patterns
```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../examples/{platform}"
. "../tests/test-framework.sh"

# Assertions
assert_equal "expected" "actual" "Test description"
assert_file_exists "path/to/file" "File exists"

# Summary
test_summary  # Prints pass/fail counts, exits 1 if failures
```

## Backward Compatibility

### Breaking Changes
Avoid breaking changes. When necessary:
- Provide migration path in documentation
- Support old and new patterns during transition
- Use deprecation warnings before removal

### Environment Variables
- Never remove environment variables
- Mark deprecated variables with warning messages
- Maintain aliases for renamed variables

### Configuration Files
- Support both old and new config formats
- Auto-migrate when possible
- Provide manual migration commands

## Debug Logging

### Enable Debug Mode
```bash
# Platform-specific
ANDROID_DEBUG=1 devbox shell
IOS_DEBUG=1 devbox shell

# Global
DEBUG=1 devbox shell
```

### Debug Functions
```bash
{platform}_debug_enabled()  # Check if debug mode is on
{platform}_debug_log "message"  # Log debug message
{platform}_debug_dump_vars VAR1 VAR2  # Dump variable values
```

### Debug Output
- Prefix: Platform name in brackets `[android]` or `[ios]`
- Stderr: All debug output goes to stderr
- Conditional: Only output when debug mode enabled

## CI/CD Patterns

### Optimization for CI
- Use lock files to minimize SDK downloads
- Skip interactive prompts with environment detection
- Disable summary printing in CI (`CI=1` or `GITHUB_ACTIONS=1`)
- Run with `--pure` flag for reproducible environments

### GitHub Actions Example
```yaml
- name: Setup Devbox
  uses: jetify-com/devbox-install-action@v0.11.0

- name: Test Android Plugin
  run: |
    EMU_HEADLESS=1 devbox run --pure start-emu max
    devbox run --pure stop-emu
```

### Performance Tips
- Select specific devices: `devices select min` reduces evaluation time
- Use lock files: Commit `devices.lock.json` to avoid regeneration
- Cache Devbox: Cache `.devbox` directory in CI for faster startups
- Parallel jobs: Test different platforms in parallel
