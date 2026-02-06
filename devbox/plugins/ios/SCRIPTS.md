# iOS Plugin Scripts Reference

This document provides a detailed reference for all scripts in the iOS plugin, their purposes, dependencies, and how they interact with each other.

## Scripts Directory Structure

```
devbox/plugins/ios/scripts/
├── env.sh           # Environment setup and Xcode resolution (sourced)
├── validate.sh      # Validation functions (sourced)
├── ios.sh           # Main CLI entry point (executable)
├── devices.sh       # Device management CLI (executable)
├── select-device.sh # Device selection helper (executable)
└── simctl.sh        # Simulator control functions (sourced)
```

## Script Categories

### 1. Sourced Library Scripts
These scripts must be sourced (not executed) and provide functions/environment for other scripts:
- `env.sh` - Core environment setup
- `validate.sh` - Validation functions
- `simctl.sh` - Simulator management functions

### 2. Executable CLI Scripts
These scripts are executed directly by users or other scripts:
- `ios.sh` - Main CLI router
- `devices.sh` - Device management commands
- `select-device.sh` - Device selection utility

## Detailed Script Documentation

---

### `env.sh`

**Purpose:** Core environment initialization script that sets up the iOS/Xcode environment, resolves paths, and loads configuration.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Load iOS plugin configuration (generated from env vars in virtenv)
2. Discover and configure Xcode developer directory
3. Set up macOS-specific environment (`DEVELOPER_DIR`, `CC`, `CXX`)
4. Configure Devbox with `--omit-nix-env` for native toolchain
5. Source validation scripts and run non-blocking validations
6. Provide debug logging utilities

**Exported Functions:**
- `ios_debug_enabled()` - Check if debug mode is on
- `ios_debug_log(message)` - Log debug message if enabled
- `ios_debug_log_script(name)` - Log script execution context
- `ios_debug_dump_vars(vars...)` - Dump variable values in debug mode
- `ios_require_tool(tool, message)` - Ensure a tool is available or exit
- `ios_require_dir(path, message)` - Ensure directory exists or exit
- `ios_require_dir_contains(base, subpath, message)` - Verify directory contains a path
- `load_ios_config()` - Load configuration (generated from env vars)
- `ios_resolve_devbox_bin()` - Find devbox executable
- `ios_latest_xcode_dev_dir()` - Find latest Xcode by version
- `ios_resolve_developer_dir()` - Resolve Xcode developer directory
- `devbox_omit_nix_env()` - Configure Devbox to use native macOS toolchain
- `ios_show_summary()` - Print resolved SDK configuration summary

**Key Environment Variables Set:**
- `DEVELOPER_DIR` - Xcode developer directory path
- `CC` - C compiler (`/usr/bin/clang`)
- `CXX` - C++ compiler (`/usr/bin/clang++`)
- `PATH` - Updated with Xcode tools and iOS scripts
- `IOS_NODE_BINARY` - Node.js binary path (if available)
- `DEVBOX_OMIT_NIX_ENV_APPLIED` - Flag that omit-nix-env was applied

**Xcode Discovery Strategy:**
1. Check `IOS_DEVELOPER_DIR` environment variable
2. Find latest Xcode in `/Applications/Xcode*.app` by version
3. Use `xcode-select -p` output
4. Fallback to `/Applications/Xcode.app/Contents/Developer`

**Devbox Integration (`devbox_omit_nix_env`):**
- Runs `devbox shellenv --omit-nix-env=true` to skip Nix environment
- Preserves macOS native toolchain (clang, Swift, etc.)
- Sets `CC=/usr/bin/clang` and `CXX=/usr/bin/clang++`
- Adds Xcode tools to PATH
- Unsets `SDKROOT` to let Xcode select appropriate SDK

**Called By:** All other scripts (must be sourced first)

**Sources:**
- `validate.sh` (if available)

**Guards:**
- Uses `IOS_ENV_LOADED` flag to prevent duplicate sourcing
- Checks PID to handle subshells correctly

**Platform Check:**
- Only applies Xcode configuration on macOS (`uname -s = Darwin`)

---

### `validate.sh`

**Purpose:** Provides non-blocking validation functions that warn about potential issues.

**Type:** Sourced library (must be sourced, not executed)

**Exported Functions:**
- `ios_validate_xcode()` - Validates Xcode installation on macOS
- `ios_validate_lock_file()` - Validates devices.lock.json checksum against device definitions

**Validation Philosophy:**
- Warnings only, never blocks execution
- Returns 0 even on validation failures
- Provides actionable fix commands in warning messages
- Skips validation when tools unavailable or platform unsupported

**`ios_validate_xcode()` Details:**
- Only runs on macOS (`uname -s = Darwin`)
- Checks if `xcode-select` command exists
- Verifies developer directory exists
- Suggests fixes: `xcode-select --install` or App Store installation

**`ios_validate_lock_file()` Details:**
- Computes SHA-256 checksum of device files
- Compares with checksum in devices.lock.json
- Warns if checksums don't match (device definitions changed)
- Lock file is optional (no warning if missing)

**Called By:**
- `env.sh` - Automatically runs validations during environment setup

**Example Output:**
```
Warning: Xcode developer directory not found.
Run 'xcode-select --install' or install Xcode from the App Store.

Warning: devices.lock.json may be stale.
Run 'devbox run ios.sh devices eval' to update.
```

---

### `ios.sh`

**Purpose:** Main CLI entry point that routes commands to appropriate handlers.

**Type:** Executable script

**Usage:**
```bash
ios.sh <command> [args]

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
- `info` - Sources `env.sh` and calls `ios_show_summary()`

**Dependencies:**
- `jq` - For config manipulation
- `devices.sh` - For device management
- `env.sh` - For info command

**Called By:** User via `devbox run ios.sh <command>`

**Sources:** None (executes other scripts)

**Identical Pattern:** Nearly identical to android.sh with platform-specific paths

---

### `devices.sh`

**Purpose:** Device management CLI for creating, updating, listing, and managing device definitions.

**Type:** Executable script

**Usage:**
```bash
devices.sh <command> [args]

Commands:
  list                      # List all device definitions
  show <name>              # Show specific device JSON
  create <name> --runtime <version>
  update <name> [--name <new>] [--runtime <version>]
  delete <name>            # Remove device definition
  select <name...>         # Select devices for evaluation
  reset                    # Reset device selection (all)
  eval                     # Generate devices.lock.json
```

**Key Functions:**
- `require_jq()` - Ensure jq is available
- `resolve_device_file(name)` - Find device JSON by filename or name field
- `validate_runtime(value)` - Ensure runtime version is valid (numeric with dots)

**Device Definition Format:**
```json
{
  "name": "iphone15",
  "runtime": "17.5"
}
```

**Lock File Generation (`eval` command):**
1. Reads `EVALUATE_DEVICES` from config (JSON array)
2. Computes SHA-256 checksum of all device files
3. Determines device names:
   - If `EVALUATE_DEVICES` is empty array: "all"
   - Otherwise: comma-separated list of selected devices
4. Writes `devices.lock.json`:
   ```json
   {
     "devices": ["min", "max"],
     "checksum": "abc123...",
     "generated_at": "2026-02-05T12:00:00Z"
   }
   ```

**Runtime Version Format:**
- Numeric with dots: `17.5`, `16.4`, `15.0`
- Get available runtimes: `xcrun simctl list runtimes`
- Uses iOS version number (not full identifier)

**Dependencies:**
- `jq` - For JSON manipulation
- `select-device.sh` - For select command
- `sha256sum` or `shasum` - For checksum computation
- `date` - For ISO 8601 timestamp

**Called By:**
- `ios.sh devices` - Via delegation
- User via `devbox run devices.sh <command>`

**Calls:**
- `select-device.sh` - When `select` command is used

**Key Differences from Android:**
- Simpler device format (only name and runtime)
- Lock file includes timestamp and device names array
- Runtime validation instead of API validation
- No tag or ABI options

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
# Output: Selected iOS devices: max

# Select multiple devices
select-device.sh min max
# Output: Selected iOS devices: min max
```

**Dependencies:**
- `jq` - For JSON manipulation

**Called By:**
- `devices.sh select` - Indirectly via command delegation

**Identical Pattern:** Nearly identical to Android version with platform-specific paths

---

### `simctl.sh`

**Purpose:** Provides functions for iOS simulator management using `xcrun simctl`.

**Type:** Sourced library (must be sourced, not executed)

**Key Functions:**

#### Configuration
- `ios_config_path()` - Resolve path to generated config
  - Tries multiple fallback locations in virtenv
  - Returns path if found

#### CoreSimulator Health
- `ensure_core_sim_service()` - Verify CoreSimulatorService is healthy
  - Runs `xcrun simctl list devices -j`
  - Detects service failures or invalid connections
  - Provides recovery commands if unhealthy
  - Example recovery:
    ```bash
    killall -9 com.apple.CoreSimulatorService 2>/dev/null || true
    launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService
    ```

#### Runtime Management
- `pick_runtime(preferred)` - Find runtime matching preferred iOS version
  - Queries available runtimes via `xcrun simctl list runtimes -j`
  - Matches by iOS version (e.g., "17.5")
  - Filters to available runtimes only
  - Returns: `identifier|name` (e.g., `com.apple.CoreSimulator.SimRuntime.iOS-17-5|iOS 17.5`)

- `resolve_runtime(preferred)` - Resolve runtime, downloading if needed
  - Tries `pick_runtime()` first
  - If not found and `IOS_DOWNLOAD_RUNTIME != 0`:
    - Runs `xcodebuild -downloadPlatform iOS`
    - Retries `pick_runtime()`
  - Falls back to any available iOS runtime

#### Simulator Operations
(Functions beyond line 100 not shown in excerpt, but typically include:)
- Creating simulators
- Booting/shutting down simulators
- Installing apps on simulators
- Launching apps
- Managing simulator state

**Dependencies:**
- `env.sh` - Must be sourced first
- `xcrun` - Xcode command-line tool
- `simctl` - iOS Simulator control tool
- `jq` - For JSON parsing
- `xcodebuild` - For downloading runtimes (optional)

**Called By:**
- Scripts that manage simulators (e.g., start-sim, setup-ios)

**Sources:**
- `env.sh`

**Guards:**
- Must be sourced, not executed
- Checks if being sourced and exits if not

**Error Handling:**
- Detects CoreSimulatorService issues
- Provides recovery instructions
- Handles missing runtimes gracefully

---

## Script Dependency Graph

```
env.sh (sourced first)
  ├─> validate.sh (sourced)
  │   └─> Runs validations (non-blocking)
  └─> Exports environment for all scripts

simctl.sh (sourced for simulator ops)
  └─> sources: env.sh

ios.sh (main CLI - executable)
  ├─> calls: devices.sh (delegation)
  └─> sources: env.sh (for info command)

devices.sh (device mgmt CLI - executable)
  └─> calls: select-device.sh (for select command)

select-device.sh (helper - executable)
  └─> (standalone utility)
```

## Execution Flow Examples

### Example 1: User runs `devbox run ios.sh info`

```
1. ios.sh executes
2. Parses command: "info"
3. Sources env.sh
   3a. env.sh sources validate.sh
   3b. env.sh runs validations (Xcode, lock file)
   3c. env.sh resolves Xcode developer directory
   3d. env.sh applies devbox_omit_nix_env
4. Calls ios_show_summary()
5. Prints Xcode and runtime information
```

### Example 2: User runs `devbox run ios.sh devices create iphone15 --runtime 17.5`

```
1. ios.sh executes
2. Parses command: "devices create ..."
3. Delegates to devices.sh via exec
4. devices.sh parses: "create iphone15 --runtime 17.5"
5. Validates runtime value (17.5)
6. Creates JSON file: devbox.d/ios/devices/iphone15.json
```

### Example 3: User runs `devbox run ios.sh devices select min max`

```
1. ios.sh executes
2. Delegates to devices.sh via exec
3. devices.sh parses: "select min max"
4. Calls select-device.sh min max
5. select-device.sh updates EVALUATE_DEVICES in the generated config to ["min", "max"]
6. Returns to devices.sh
7. devices.sh does NOT automatically call eval (unlike Android)
```

### Example 4: Script sources simctl.sh for simulator operations

```
1. Script sources simctl.sh
   1a. simctl.sh checks if being sourced (else exits)
   1b. simctl.sh sources env.sh
       - env.sh loads config
       - env.sh resolves Xcode
       - env.sh applies omit-nix-env
       - env.sh sources validate.sh
2. Script can now call simulator functions like:
   - ensure_core_sim_service
   - resolve_runtime "17.5"
   - pick_runtime "16.4"
```

### Example 5: Environment setup on macOS

```
1. env.sh is sourced
2. load_ios_config() reads generated config
3. validate.sh is sourced
4. Validations run (non-blocking):
   - ios_validate_xcode()
   - ios_validate_lock_file()
5. devbox_omit_nix_env() executes:
   5a. Resolves devbox binary
   5b. Runs: devbox shellenv --omit-nix-env=true
   5c. Sets CC=/usr/bin/clang
   5d. Sets CXX=/usr/bin/clang++
   5e. Resolves DEVELOPER_DIR
6. ios_resolve_developer_dir() finds Xcode:
   6a. Try IOS_DEVELOPER_DIR env var
   6b. Try latest Xcode by version (parsing Info.plist)
   6c. Try xcode-select -p
   6d. Fallback to /Applications/Xcode.app/Contents/Developer
7. PATH updated with:
   - $DEVELOPER_DIR/usr/bin
   - /usr/bin:/bin:/usr/sbin:/sbin
   - IOS_SCRIPTS_DIR
8. Scripts made executable (chmod +x)
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
if ios_debug_enabled; then
  ios_debug_log "message"
fi
```

### Non-Blocking Validation Pattern
```bash
ios_validate_something || true  # Always succeeds
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

### Xcode Version Parsing Pattern
```bash
# Using PlistBuddy to read Xcode version
version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "$app/Contents/Info.plist" 2>/dev/null || printf '0')"
```

## iOS-Specific Considerations

### macOS Platform Requirement
- iOS plugin only works on macOS
- Scripts check `uname -s = Darwin` before applying macOS-specific logic
- Xcode validation skipped on non-macOS platforms

### Xcode Integration
- Uses system Xcode installation (not packaged)
- Relies on Xcode command-line tools (xcrun, xcodebuild, simctl)
- Developer directory must be set for proper operation

### Devbox Omit-Nix-Env
- Critical for iOS: Must use native macOS toolchain, not Nix toolchain
- Prevents Nix compiler from interfering with Xcode builds
- Preserves Apple SDK paths and Swift compiler

### CoreSimulatorService
- macOS service that manages simulators
- Can become unhealthy and require restart
- Scripts detect and provide recovery instructions

### Runtime Downloads
- iOS simulator runtimes can be downloaded via xcodebuild
- `IOS_DOWNLOAD_RUNTIME` controls automatic downloads
- Large downloads (~7GB per runtime)

## Best Practices When Modifying Scripts

1. **macOS-Only Operations:**
   - Always check `[ "$(uname -s)" = "Darwin" ]` before macOS-specific code
   - Provide meaningful messages on non-macOS platforms

2. **Xcode Discovery:**
   - Support multiple discovery methods (env var, version-based, xcode-select)
   - Handle missing Xcode gracefully with actionable error messages

3. **Devbox Integration:**
   - Preserve omit-nix-env setup to avoid toolchain conflicts
   - Don't override `CC`, `CXX`, or `DEVELOPER_DIR` after setup

4. **Simulator Operations:**
   - Always check CoreSimulatorService health before operations
   - Handle runtime downloads gracefully (large, slow)
   - Provide recovery instructions for service failures

5. **Error Handling:**
   - CLI scripts use `set -eu` for strict error handling
   - Validation functions return 0 and use `|| true` when called
   - Provide recovery commands in error messages

6. **Runtime Resolution:**
   - Use iOS version numbers (17.5), not full identifiers
   - Filter to available runtimes only
   - Support automatic downloads when configured

## Debugging Scripts

Enable debug mode:
```bash
IOS_DEBUG=1 devbox shell
# or
DEBUG=1 devbox shell
```

Debug output shows:
- Script execution context (sourced vs run)
- Configuration file loaded
- Environment variable values
- Xcode resolution steps
- Developer directory path

Check Xcode configuration:
```bash
# Show Xcode info
devbox run ios.sh info

# Check Xcode developer directory
xcode-select -p

# List available runtimes
xcrun simctl list runtimes

# Check CoreSimulatorService status
xcrun simctl list devices
```

## Troubleshooting Common Issues

### Issue: "CoreSimulatorService connection became invalid"
**Solution:**
```bash
killall -9 com.apple.CoreSimulatorService 2>/dev/null || true
launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService
open -a Simulator  # Open once to initialize
```

### Issue: "Xcode developer directory not found"
**Solution:**
```bash
# Install Xcode command-line tools
xcode-select --install

# Or set developer directory manually
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Issue: "Runtime iOS X.X not found"
**Solution:**
```bash
# Download runtime via xcodebuild
xcodebuild -downloadPlatform iOS

# Or set IOS_DOWNLOAD_RUNTIME=1 for automatic downloads
export IOS_DOWNLOAD_RUNTIME=1
```

### Issue: "devbox: command not found" in simctl.sh
**Solution:**
- Ensure devbox is in PATH
- Set `DEVBOX_BIN` environment variable explicitly
- Check `DEVBOX_INIT_PATH` is set correctly
