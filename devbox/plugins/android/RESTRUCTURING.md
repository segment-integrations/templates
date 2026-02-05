# Android Plugin Restructuring

## Summary

The Android plugin scripts have been reorganized to reduce complexity and improve logical grouping of functionality. The restructuring eliminates duplicate files and consolidates closely related functionality.

## Changes Made

### File Consolidation

**Merged into `avd.sh`:**
- `avd-device.sh` - Device resolution and system image matching
- `avd-create.sh` - AVD creation and management
- `android-reset.sh` - AVD reset functionality (device-specific or full reset)

**Result:** One consolidated `avd.sh` file (736 lines) that handles all AVD-related operations.

**Removed files:**
- `avd-device.sh` (deleted)
- `avd-create.sh` (deleted)
- `android-reset.sh` (deleted)
- `select-device.sh` (deleted - functionality moved to `devices.sh`)

### Functional Improvements

**1. Device Selection**
- Moved from standalone `select-device.sh` to `devices.sh` as a command
- Usage: `devices.sh select <device-name...>`
- Automatically regenerates lock file after selection

**2. AVD Reset**
- Now supports device-specific reset: `android_reset_avds <device-name>`
- Full reset: `android_reset_avds` (no arguments)
- Safety: Only removes AVDs within project sandbox (ANDROID_SDK_HOME scope)

**3. Script Organization**

The plugin now has a cleaner architecture:

```
avd.sh          - AVD management (device resolution, creation, reset)
                  + wrapper that sources emulator.sh and deploy.sh
emulator.sh     - Emulator lifecycle (start, stop, service mode)
deploy.sh       - App deployment (build, install, launch)
devices.sh      - Device definitions CLI (create, update, select, eval)
lib.sh          - Shared utilities
env.sh          - Environment setup
validate.sh     - Non-blocking validation
android.sh      - Main CLI entry point
```

### API Compatibility

**Maintained functions:**
- `android_service()` - Alias for `android_run_emulator_service()`
- `android_run_app()` - Alias for `android_deploy_app()`
- All existing AVD setup and emulator functions remain available

**New functions:**
- `android_reset_avds([device_name])` - Reset AVD state (replaces `android_reset_state`)
- `android_delete_avd(avd_name)` - Delete specific AVD by name

### Testing Updates

**Fixed test framework:**
- `assert_failure()` now runs commands in subshell to prevent `exit` from killing test script
- All 33 tests passing (20 lib.sh + 13 devices.sh)

**Linting:**
- Shellcheck configured to only fail on warnings/errors (not info messages)
- All scripts pass shellcheck validation

## Benefits

1. **Reduced Complexity**: 4 fewer script files to maintain
2. **Better Organization**: Related functionality is now grouped together
3. **Clearer Separation**: AVD management vs emulator lifecycle vs deployment
4. **Enhanced Reset**: Can now reset specific devices or all devices
5. **Unified Device Management**: All device operations in one CLI (`devices.sh`)

## Migration Notes

- No changes required for existing code using `android_service()` or `android_run_app()`
- Scripts that sourced `avd-device.sh`, `avd-create.sh`, or `android-reset.sh` should now source `avd.sh`
- `select-device.sh` removed - use `devices.sh select` instead
- `android_reset_state()` deprecated - use `android_reset_avds()` instead

## Files Modified

- `devbox/plugins/android/scripts/avd.sh` - Consolidated from 35 lines to 736 lines
- `devbox/plugins/android/scripts/devices.sh` - Added select/reset commands inline
- `devbox/plugins/android/plugin.json` - Updated file references
- `devbox.json` - Fixed shellcheck severity level
- `devbox/plugins/tests/android/test-lib.sh` - Fixed subshell issue in assert_failure
