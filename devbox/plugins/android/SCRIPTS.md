# Android Plugin Scripts Reference

This document provides a detailed reference for all scripts in the Android plugin, their purposes, dependencies, and how they interact with each other.

## Available Commands

### Build & Test Commands
- `devbox run build-android` - Build Android app with info logging
- `devbox run build-android-debug` - Build with full debug output
- `devbox run test-android` - Run unit tests
- `devbox run test-android-e2e` - Run end-to-end tests on emulator

### Emulator Commands
- `devbox run start-android [device]` - Start emulator and deploy app
- `devbox run stop-emu` - Stop all running emulators
- `devbox run reset-emu` - Stop and reset all emulators (cleans AVD state)
- `devbox run reset-emu-device <name>` - Stop and reset specific device

### Device Management
- `devbox run android.sh devices list` - List all device definitions
- `devbox run android.sh devices show <name>` - Show device details
- `devbox run android.sh devices create <name> --api <n> --device <id>` - Create device
- `devbox run android.sh devices update <name> [options]` - Update device
- `devbox run android.sh devices delete <name>` - Delete device
- `devbox run android.sh devices select <names...>` - Select devices for evaluation
- `devbox run android.sh devices reset` - Reset device selection (all devices)
- `devbox run android.sh devices eval` - Generate devices.lock.json

### Gradle Utilities
- `devbox run gradle-clean` - Clean Gradle build artifacts
- `devbox run gradle-stop` - Stop Gradle daemon

### Configuration
- `devbox run android.sh config show` - Display generated configuration (from env vars)
- `devbox run android.sh config set KEY=VALUE` - Update configuration
- `devbox run android.sh info` - Display resolved SDK information

## Scripts Directory Structure

```
devbox/plugins/android/scripts/
├── env.sh       # Environment setup and SDK resolution (sourced)
├── lib.sh       # Utility functions library (sourced)
├── validate.sh  # Validation functions (sourced)
├── avd.sh       # AVD management, device resolution, reset (sourced)
├── emulator.sh  # Emulator lifecycle (start, stop, service) (sourced)
├── deploy.sh    # App deployment (build, install, launch) (sourced)
├── android.sh   # Main CLI entry point (executable)
└── devices.sh   # Device management CLI (executable)
```

## Script Categories

### 1. Sourced Library Scripts
These scripts must be sourced (not executed) and provide functions/environment for other scripts:
- `env.sh` - Core environment setup
- `lib.sh` - Utility functions
- `validate.sh` - Validation functions
- `avd.sh` - AVD management (includes device resolution, AVD creation, reset)
- `emulator.sh` - Emulator lifecycle management
- `deploy.sh` - Application deployment pipeline

### 2. Executable CLI Scripts
These scripts are executed directly by users or other scripts:
- `android.sh` - Main CLI router
- `devices.sh` - Device management commands (includes device selection)

## Detailed Script Documentation

---

### `env.sh`

**Purpose:** Core environment initialization script that sets up the Android SDK environment, resolves paths, and loads configuration.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Load Android plugin configuration (generated from env vars in virtenv)
2. Resolve Android SDK root (via Nix flake or local SDK)
3. Set up Android environment variables (`ANDROID_SDK_ROOT`, `ANDROID_HOME`, `ANDROID_AVD_HOME`, etc.)
4. Configure PATH to include SDK tools and plugin scripts
5. Source validation scripts and run non-blocking validations
6. Provide debug logging utilities

**Exported Functions:**
- `android_debug_enabled()` - Check if debug mode is on
- `android_debug_log(message)` - Log debug message if enabled
- `android_debug_log_script(name)` - Log script execution context
- `android_require_tool(tool, message)` - Ensure a tool is available or exit
- `android_require_dir_contains(base, subpath, message)` - Verify directory contains a path
- `android_debug_dump_vars(vars...)` - Dump variable values in debug mode
- `load_android_config()` - Load configuration (generated from env vars)
- `resolve_flake_sdk_root(output)` - Resolve SDK from Nix flake
- `detect_sdk_root_from_sdkmanager()` - Detect SDK from sdkmanager location
- `detect_sdk_root_from_tools()` - Detect SDK from adb/emulator location
- `android_show_summary()` - Print resolved SDK configuration summary

**Key Environment Variables Set:**
- `ANDROID_SDK_ROOT` - Android SDK installation path
- `ANDROID_HOME` - Alias for SDK root (compatibility)
- `ANDROID_USER_HOME` - User state directory (project-local)
- `ANDROID_AVD_HOME` - AVD definitions directory
- `ANDROID_EMULATOR_HOME` - Emulator configuration directory
- `PATH` - Updated with SDK tools and scripts

**SDK Resolution Strategy:**
1. If `ANDROID_LOCAL_SDK=1`: Try `ANDROID_SDK_ROOT` → `ANDROID_HOME` → detect from sdkmanager
2. Otherwise: Try Nix flake → sdkmanager → adb/emulator tools
3. Exits if SDK not found and `ANDROID_SDK_REQUIRED=1` (default)

**Called By:** All other scripts (must be sourced first)

**Sources:**
- `validate.sh` (if available)

**Guards:**
- Uses `ANDROID_ENV_LOADED` flag to prevent duplicate sourcing
- Checks PID to handle subshells correctly

---

### `lib.sh`

**Purpose:** Provides utility functions for string manipulation used by other scripts.

**Type:** Sourced library (must be sourced, not executed)

**Exported Functions:**
- `android_normalize_name(name)` - Normalize name to lowercase alphanumeric
- `android_sanitize_avd_name(name)` - Sanitize name for AVD use (allows `._-`)

**Called By:**
- `avd.sh` - For device name matching and AVD name generation

**Guards:**
- Uses `ANDROID_LIB_LOADED` flag to prevent duplicate sourcing
- Checks PID to handle subshells correctly

---

### `validate.sh`

**Purpose:** Provides non-blocking validation functions that warn about potential issues.

**Type:** Sourced library (must be sourced, not executed)

**Exported Functions:**
- `android_validate_lock_file()` - Validates devices.lock.json checksum against device definitions
- `android_validate_sdk()` - Validates ANDROID_SDK_ROOT points to existing directory

**Validation Philosophy:**
- Warnings only, never blocks execution
- Returns 0 even on validation failures
- Provides actionable fix commands in warning messages
- Skips validation when tools unavailable (e.g., sha256sum)

**Called By:**
- `env.sh` - Automatically runs validations during environment setup

**Example Output:**
```
Warning: devices.lock.json may be stale (device definitions changed).
Run 'devbox run android.sh devices eval' to update.
```

---

### `android.sh`

**Purpose:** Main CLI entry point that routes commands to appropriate handlers.

**Type:** Executable script

**Usage:**
```bash
android.sh <command> [args]

Commands:
  devices <command> [args]  # Delegate to devices.sh
  config show              # Show generated config (from env vars)
  config set KEY=VALUE     # Update config values
  config reset             # Reset to default config
  info                     # Show SDK summary
```

**Command Handlers:**
- `devices` - Delegates to `devices.sh`
- `config show` - Uses `cat` to display config
- `config set` - Uses `jq` to update config values
- `config reset` - Copies default config from plugin
- `info` - Sources `env.sh` and calls `android_show_summary()`

**Dependencies:**
- `jq` - For config manipulation
- `devices.sh` - For device management
- `env.sh` - For info command

**Called By:** User via `devbox run android.sh <command>`

**Sources:** None (executes other scripts)

---

### `devices.sh`

**Purpose:** Device management CLI for creating, updating, listing, and managing device definitions.

**Type:** Executable script

**Usage:**
```bash
devices.sh <command> [args]

Commands:
  list                     # List all device definitions
  show <name>             # Show specific device JSON
  create <name> --api <n> --device <id> [--tag <tag>] [--abi <abi>]
  update <name> [--name <new>] [--api <n>] [--device <id>] [--tag <tag>] [--abi <abi>]
  delete <name>           # Remove device definition
  select <name...>        # Select devices for evaluation
  reset                   # Reset device selection (all)
  eval                    # Generate devices.lock.json
```

**Key Functions:**
- `require_jq()` - Ensure jq is available
- `resolve_device_file(name)` - Find device JSON by filename or name field
- `validate_api(value)` - Ensure API is numeric
- `validate_tag(value)` - Ensure tag is valid
- `validate_abi(value)` - Ensure ABI is valid

**Device Definition Format:**
```json
{
  "name": "pixel",
  "api": 28,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

**Lock File Generation (`eval` command):**
1. Reads `EVALUATE_DEVICES` from config
2. If empty, includes all devices
3. If specified, includes only selected devices
4. Extracts API versions from matching devices
5. Adds any extra APIs from `ANDROID_PLATFORM_VERSIONS`
6. Computes SHA-256 checksum of all device files
7. Writes `devices.lock.json`:
   ```json
   {
     "api_versions": [28, 35, 36],
     "checksum": "abc123..."
   }
   ```

**Valid Tags:**
- `default`
- `google_apis`
- `google_apis_playstore`
- `play_store`
- `aosp_atd`
- `google_atd`

**Valid ABIs:**
- `arm64-v8a`
- `x86_64`
- `x86`

**Dependencies:**
- `jq` - For JSON manipulation
- `select-device.sh` - For select command
- `sha256sum` or `shasum` - For checksum computation

**Called By:**
- `android.sh devices` - Via delegation
- User via `devbox run devices.sh <command>`

**Calls:**
- `select-device.sh` - When `select` command is used

---

### `select-device.sh`

**Purpose:** Helper script to update EVALUATE_DEVICES in the generated configuration.

**Type:** Executable script

**Usage:**
```bash
select-device.sh <device-name> [device-name...]
```

**Functionality:**
1. Takes device names as arguments
2. Converts to JSON array using jq
3. Updates `.EVALUATE_DEVICES` in the generated config JSON
4. Prints confirmation message

**Example:**
```bash
# Select only max device
select-device.sh max
# Output: Selected Android devices: max

# Select multiple devices
select-device.sh min max
# Output: Selected Android devices: min max
```

**Dependencies:**
- `jq` - For JSON manipulation

**Called By:**
- `devices.sh select` - Indirectly via command delegation

---

### `avd.sh`

**Purpose:** Provides functions for AVD (Android Virtual Device) management and emulator operations.

**Type:** Sourced library (must be sourced, not executed)

**Key Functions:**

#### Java Resolution
- `resolve_java_home()` - Find Java installation
  - Priority: `ANDROID_JAVA_HOME` → `JAVA_HOME` → java in PATH
  - Returns: Path to Java home directory

#### AVD Manager Wrapper
- `run_avdmanager(args...)` - Execute avdmanager with correct JAVA_HOME

#### Device Resolution
- `detect_sdk_root()` - Get Android SDK root
- `avd_exists(name)` - Check if AVD already exists
- `resolve_device(desired)` - Find device ID from user input
  - Normalizes input and matches against available devices
  - Handles spaces, underscores, and case variations

#### System Image Resolution
- Functions to find and select appropriate system images (not shown in excerpt)

**Dependencies:**
- `env.sh` - Must be sourced first
- `lib.sh` - For name normalization functions
- `avdmanager` - Android SDK tool
- Java runtime

**Called By:**
- Scripts that manage emulators (e.g., start-emu, create AVDs)

**Sources:**
- `env.sh`
- `lib.sh`

**Guards:**
- Must be sourced, not executed
- Checks if being sourced and exits if not

---

## Script Dependency Graph

```
env.sh (sourced first)
  ├─> validate.sh (sourced)
  │   └─> Runs validations (non-blocking)
  └─> Exports environment for all scripts

lib.sh (sourced independently)
  └─> Provides utility functions

avd.sh (sourced for emulator ops)
  ├─> sources: env.sh
  └─> sources: lib.sh

android.sh (main CLI - executable)
  ├─> calls: devices.sh (delegation)
  └─> sources: env.sh (for info command)

devices.sh (device mgmt CLI - executable)
  └─> calls: select-device.sh (for select command)

select-device.sh (helper - executable)
  └─> (standalone utility)
```

## Execution Flow Examples

### Example 1: User runs `devbox run android.sh info`

```
1. android.sh executes
2. Parses command: "info"
3. Sources env.sh
   3a. env.sh sources validate.sh
   3b. env.sh runs validations
   3c. env.sh resolves SDK and sets environment
4. Calls android_show_summary()
5. Prints SDK information
```

### Example 2: User runs `devbox run android.sh devices create pixel_api28 --api 28 --device pixel`

```
1. android.sh executes
2. Parses command: "devices create ..."
3. Delegates to devices.sh via exec
4. devices.sh parses: "create pixel_api28 --api 28 --device pixel"
5. Validates API value (28)
6. Creates JSON file: devbox.d/android/devices/pixel_api28.json
```

### Example 3: User runs `devbox run android.sh devices select max`

```
1. android.sh executes
2. Delegates to devices.sh via exec
3. devices.sh parses: "select max"
4. Calls select-device.sh max
5. select-device.sh updates EVALUATE_DEVICES in the generated config
6. Returns to devices.sh
7. devices.sh calls itself recursively: devices.sh eval
8. eval generates devices.lock.json with max device's API
```

### Example 4: Script sources avd.sh for emulator operations

```
1. Script sources avd.sh
   1a. avd.sh checks if being sourced (else exits)
   1b. avd.sh sources env.sh
       - env.sh loads config
       - env.sh resolves SDK
       - env.sh sources validate.sh
   1c. avd.sh sources lib.sh
2. Script can now call AVD functions like:
   - avd_exists "pixel_28"
   - resolve_device "pixel"
```

## Environment Variable Loading Priority

Scripts use a consistent pattern for finding configuration:

1. `${PLATFORM}_CONFIG_DIR` environment variable
2. `${DEVBOX_PROJECT_ROOT}/devbox.d/platform/`
3. `${DEVBOX_PROJECT_DIR}/devbox.d/platform/`
4. `${DEVBOX_WD}/devbox.d/platform/`
5. `./devbox.d/platform/` (current directory)

## Common Patterns

### Sourcing Guard Pattern
```bash
if ! (return 0 2>/dev/null); then
  echo "script.sh must be sourced." >&2
  exit 1
fi

if [ "${SCRIPT_LOADED:-}" = "1" ] && [ "${SCRIPT_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
SCRIPT_LOADED=1
SCRIPT_LOADED_PID="$$"
```

### Debug Logging Pattern
```bash
if android_debug_enabled; then
  android_debug_log "message"
fi
```

### Non-Blocking Validation Pattern
```bash
android_validate_something || true  # Always succeeds
```

### Config Loading Pattern
```bash
jq -r 'to_entries[] | "\(.key)\t\(.value|tostring)"' "$config_path" | \
while IFS=$'\t' read -r key value; do
  # Only set if not already set
  current="$(eval "printf '%s' \"\${$key-}\"")"
  if [ -z "$current" ] && [ -n "$value" ]; then
    eval "$key=\"\$value\""
    export "$key"
  fi
done
```

## Best Practices When Modifying Scripts

1. **Sourced vs Executable:** Respect the script type
   - Sourced libraries must check `(return 0 2>/dev/null)` guard
   - Use sourcing guards to prevent duplicate loading

2. **Error Handling:**
   - CLI scripts use `set -eu` for strict error handling
   - Validation functions return 0 and use `|| true` when called

3. **Environment Variables:**
   - Always check if variable is already set before overriding
   - Use consistent naming: `ANDROID_*` prefix

4. **Debug Logging:**
   - Use `android_debug_log()` for debug output
   - Check `android_debug_enabled()` before expensive operations

5. **Path Resolution:**
   - Try multiple fallback strategies
   - Support both explicit env vars and auto-detection

6. **Tool Dependencies:**
   - Check tool availability with `command -v`
   - Provide helpful error messages with installation hints

7. **JSON Manipulation:**
   - Always use `jq` for JSON operations
   - Validate input before updating files
   - Use temp files and atomic moves: `jq ... > tmp && mv tmp original`

## Debugging Scripts

Enable debug mode:
```bash
ANDROID_DEBUG=1 devbox shell
# or
DEBUG=1 devbox shell
```

Debug output shows:
- Script execution context (sourced vs run)
- Configuration file loaded
- Environment variable values
- SDK resolution steps
