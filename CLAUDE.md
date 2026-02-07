# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a mobile development templates repository providing Devbox plugins and example projects for Android, iOS, and React Native. The plugins enable project-local, reproducible mobile development environments without touching global state (e.g., `~/.android`).

## Core Architecture

### Plugin System

Three main plugins are located in `plugins/`:

1. **android** - Android SDK + emulator management via Nix flake
   - SDK flake: `devbox.d/android/flake.nix`
   - Device definitions: `devbox.d/android/devices/*.json`
   - Scripts: `.devbox/virtenv/android/scripts/`
   - Configuration: Environment variables in `plugin.json`

2. **ios** - iOS toolchain + simulator management for macOS
   - Device definitions: `devbox.d/ios/devices/*.json`
   - Scripts: `.devbox/virtenv/ios/scripts/`
   - Configuration: Environment variables in `plugin.json`

3. **react-native** - Composition layer over Android + iOS plugins
   - Inherits both Android and iOS device management
   - Enables cross-platform React Native development

### Key Concepts

**Device Definitions**: JSON files defining emulator/simulator configurations
- Android: `{name, api, device, tag, preferred_abi}`
- iOS: `{name, runtime}`
- Default devices: `min.json` and `max.json`

**Lock Files**: `devices/devices.lock` optimizes CI by limiting which SDK versions are evaluated
- Generated via `{platform}.sh devices eval`
- Contains checksums of device definitions for validation

**Caching**: Nix handles flake evaluation caching internally
- iOS: `.xcode_dev_dir.cache`, `.shellenv.cache` for expensive shell operations
- No custom Android SDK caching needed - Nix manages this

**Environment Scoping**: All plugins follow naming patterns:
- `{PLATFORM}_CONFIG_DIR` - Configuration directory
- `{PLATFORM}_DEVICES_DIR` - Device definitions
- `{PLATFORM}_SCRIPTS_DIR` - Runtime scripts
- `{PLATFORM}_DEFAULT_DEVICE` - Default device selection
- `ANDROID_DEVICES` - Android devices to evaluate (comma-separated, empty = all)
- `IOS_DEVICES` - iOS devices to evaluate (comma-separated, empty = all)

## Common Commands

### Devbox CLI Usage

**IMPORTANT:**
- `devbox run` executes commands/scripts (can run ANY binary in PATH, not just devbox.json scripts)
- `devbox shell` starts interactive shell (NOT for running commands)

```bash
# Execute commands (preferred)
devbox run test                    # Run script from devbox.json
devbox run android.sh devices list # Run any binary in PATH
devbox run --pure pytest tests/    # Isolated environment
devbox run --list                  # List available scripts

# Interactive shell (for exploration only)
devbox shell                       # Enter shell with packages

# Package management
devbox add python@3.11             # Add package
devbox list                        # List packages
devbox init                        # Create devbox.json
```

### Using Devbox MCP Tools (Model Context Protocol)

**IMPORTANT: Always prefer devbox-mcp tools over direct Bash commands when available.**

This repository includes a devbox-mcp plugin that provides MCP tools for interacting with devbox. These tools should be your first choice because they:
- Run commands in the correct devbox environment with all packages available
- Automatically use the project's `devbox.json` configuration
- Handle environment variables and PATH correctly
- Work across different project directories via the `cwd` parameter

**Preferred approach:**
```javascript
// Use devbox-mcp tools
devbox_run({ command: "android.sh devices list", cwd: "/path/to/project" })
devbox_run({ command: "test", cwd: "/path/to/project" })
devbox_list({ cwd: "/path/to/project" })
```

**Avoid when possible:**
```bash
# Direct Bash commands run outside devbox environment
bash -c "cd /path/to/project && android.sh devices list"
```

**When you need Bash commands, wrap them with devbox_run:**
```javascript
// This ensures the command runs in the devbox environment
devbox_run({
  command: "bash",
  args: ["-c", "echo $ANDROID_SDK_ROOT"],
  cwd: "/path/to/project"
})
```

**Available devbox-mcp tools:**
- `devbox_run` - Execute any command or script in devbox environment
- `devbox_list` - List installed packages
- `devbox_add` - Add packages to devbox.json
- `devbox_info` - Get package information
- `devbox_search` - Search Nix package registry
- `devbox_shell_env` - Get environment variables
- `devbox_init` - Initialize devbox.json
- `devbox_docs_search` - Search devbox documentation
- `devbox_docs_list` - List available docs
- `devbox_docs_read` - Read documentation files

All tools (except `devbox_search`) support the `cwd` parameter to specify which project directory to operate in.

### Setup
```bash
# Install devbox dependencies
devbox shell

# Validate plugin installation
cd examples/{android|ios|react-native}
devbox shell
```

### Device Management

#### Android
```bash
# List devices
devbox run --pure android.sh devices list

# Create/update/delete devices
devbox run --pure android.sh devices create pixel_api28 --api 28 --device pixel --tag google_apis
devbox run --pure android.sh devices update pixel_api28 --api 29
devbox run --pure android.sh devices delete pixel_api28

# Regenerate lock file (after creating/updating/deleting devices)
devbox run --pure android.sh devices eval

# Sync AVDs to match device definitions
devbox run --pure android.sh devices sync

# View configuration
devbox run --pure android.sh config show

# Override configuration (set in devbox.json)
# {
#   "include": ["plugin:android"],
#   "env": {
#     "ANDROID_DEFAULT_DEVICE": "max",
#     "ANDROID_DEVICES": "min,max"
#   }
# }
```

#### iOS
```bash
# List devices
devbox run --pure ios.sh devices list

# Create/update/delete devices
devbox run --pure ios.sh devices create iphone15 --runtime 17.5
devbox run --pure ios.sh devices update iphone15 --runtime 18.0
devbox run --pure ios.sh devices delete iphone15

# Regenerate lock file (after creating/updating/deleting devices)
devbox run --pure ios.sh devices eval

# Sync simulators to match device definitions
devbox run --pure ios.sh devices sync

# View configuration
devbox run --pure ios.sh config show

# Override configuration (set in devbox.json)
# {
#   "include": ["plugin:ios"],
#   "env": {
#     "IOS_DEFAULT_DEVICE": "max",
#     "IOS_DEVICES": "min,max"
#   }
# }
```

### Building and Running

#### Android
```bash
cd examples/android

# Build the app
devbox run --pure build-android

# Start emulator
devbox run --pure start-emu [device]  # Defaults to ANDROID_DEFAULT_DEVICE

# Build, install, and launch app on emulator
devbox run --pure start-app [device]

# Stop emulator
devbox run --pure stop-emu
```

#### iOS
```bash
cd examples/ios

# Build the app
devbox run --pure build-ios

# Start simulator
devbox run --pure start-sim [device]  # Defaults to IOS_DEFAULT_DEVICE

# Build, install, and launch app on simulator
devbox run --pure start-ios [device]

# Stop simulator
devbox run --pure stop-sim
```

#### React Native
```bash
cd examples/react-native

# Install dependencies
npm install

# Android workflow
devbox run --pure start-emu [device]
devbox run --pure start-app [device]
devbox run --pure stop-emu

# iOS workflow
devbox run --pure start-sim [device]
devbox run --pure start-ios [device]
devbox run --pure stop-sim

# Build for all platforms
devbox run build  # Runs build-android, build-ios, build-web
```

### Testing

#### Plugin Tests
```bash
# Run Android plugin tests
cd plugins/tests/android
./test-*.sh

# Run iOS plugin tests
cd plugins/tests/ios
./test-*.sh
```

#### CI Workflows
```bash
# Validate locally with act (requires Docker)
act -j android-plugin-tests
act -j ios-plugin-tests
```

## Project Structure

```
.
├── plugins/
│   ├── android/          # Android plugin
│   │   ├── config/       # Default config templates
│   │   ├── scripts/      # Runtime scripts (android.sh, avd.sh, etc.)
│   │   ├── plugin.json   # Plugin manifest
│   │   └── REFERENCE.md  # Complete API reference
│   ├── ios/              # iOS plugin
│   │   ├── config/
│   │   ├── scripts/
│   │   ├── plugin.json
│   │   └── REFERENCE.md
│   ├── react-native/     # React Native plugin
│   │   ├── plugin.json
│   │   └── REFERENCE.md
│   ├── tests/            # Plugin unit tests
│   └── CONVENTIONS.md    # Plugin development patterns
├── examples/
│   ├── android/          # Minimal Android app
│   │   ├── devbox.d/     # Device definitions and config
│   │   └── devbox.json   # Includes android plugin
│   ├── ios/              # Swift package example
│   │   ├── devbox.d/
│   │   └── devbox.json   # Includes ios plugin
│   └── react-native/     # React Native app
│       ├── devbox.d/     # Both Android and iOS devices
│       └── devbox.json   # Includes react-native plugin
├── tests/                # E2E test scripts
│   ├── e2e-android.sh
│   ├── e2e-ios.sh
│   ├── e2e-react-native.sh
│   ├── e2e-sequential.sh
│   └── e2e-all.sh
├── .github/workflows/
│   ├── pr-checks.yml     # Fast PR validation (~15-30 min)
│   └── e2e-full.yml      # Full E2E tests (~45-60 min per platform)
└── devbox.json           # Root devbox config
```

## Development Patterns

### Working with Plugins

When modifying plugins:

1. Plugin configuration is in `plugin.json` (init hooks, env vars, scripts)
2. Runtime scripts go in `scripts/` directory
3. Follow conventions in `plugins/CONVENTIONS.md`:
   - Use `{platform}_` prefixes for functions
   - `set -euo pipefail` for safety
   - Non-blocking validation (warn, don't fail)
   - Debug logging via `{PLATFORM}_DEBUG=1`

### Script Layering Architecture

Plugin scripts are organized into strict layers to prevent circular dependencies. **Critical rule**: scripts can only source/depend on scripts from **earlier layers**, never from the same layer or later layers.

```
scripts/
├── lib/        # Layer 1: Pure utilities
├── platform/   # Layer 2: SDK/platform setup
├── domain/     # Layer 3: Domain operations (AVD, emulator, deploy)
├── user/       # Layer 4: User-facing CLI
└── init/       # Layer 5: Environment initialization
```

**Key principles:**
- **lib/**: Pure utility functions, no platform-specific logic
- **platform/**: SDK resolution, PATH setup, device configuration
- **domain/**: Internal domain operations - atomic, independent, orchestrated by layer 4
- **user/**: User-facing CLI commands (android.sh, devices.sh) - orchestrates domain operations
- **init/**: Environment initialization run by devbox hooks

**Critical**: Domain layer scripts cannot call each other. If two domain scripts need the same functionality, that functionality must be moved to the platform or lib layer. The user layer orchestrates multiple domain operations.

See `plugins/android/scripts/LAYERS.md` for complete documentation.

### Device Management Workflow

1. Device definitions are JSON files in `devbox.d/{platform}/devices/`
2. Modify devices using CLI commands (not manual editing)
3. After changes, regenerate lock file: `{platform}.sh devices eval`
4. Lock files should be committed to optimize CI

### Adding New Devices

```bash
# Android - specify API level and device profile
devbox run --pure android.sh devices create pixel_api30 \
  --api 30 \
  --device pixel \
  --tag google_apis \
  --preferred_abi x86_64

# iOS - specify simulator runtime version
devbox run --pure ios.sh devices create iphone14 --runtime 16.4

# Regenerate lock file after adding
devbox run --pure {platform}.sh devices eval
```

### Debugging

Enable debug logging:
```bash
# Platform-specific
ANDROID_DEBUG=1 devbox shell
IOS_DEBUG=1 devbox shell

# Global
DEBUG=1 devbox shell
```

Check cache validity:
```bash
# iOS - view cached Xcode path
cat .devbox/virtenv/ios/.xcode_dev_dir.cache

# Android SDK - Nix handles caching internally (no cache file to check)
```

Validate lock files:
```bash
devbox run --pure android.sh devices eval
devbox run --pure ios.sh devices eval
```

## Contributing Guidelines

### Code Philosophy

**Simplicity and readability first.** Code should be easy to understand at a glance. Prefer straightforward solutions over clever ones. If you need to explain what code does, the code is probably too complex.

**DRY and single responsibility.** Extract repeated logic into functions with clear names. Each function should do one thing well. Each file should have a focused purpose.

**Keep files focused and manageable.** Don't let files grow with unrelated functions. Split large files by concern:
- `lib.sh` - Generic utilities (path manipulation, JSON parsing, logging)
- `devices.sh` - Device management operations
- `avd.sh` - AVD-specific operations
- `env.sh` - Environment variable setup

When a file exceeds ~500 lines or contains unrelated functions, split it.

**Minimal comments in code.** Write self-documenting code with clear function and variable names. Use comments only for:
- Why decisions were made (not what the code does)
- Complex algorithms that can't be simplified
- Workarounds for external tool bugs

Document public APIs exhaustively in REFERENCE.md files, not in code comments.

**Fail loudly, avoid fallbacks.** When something is wrong, the code should exit with a clear error message and non-zero status. Avoid silent fallbacks that hide problems.

**Reduce edge cases and unexpected behavior.** Design for the common path. When edge cases arise, validate assumptions early and fail fast rather than adding complex branching logic.

**Scripts fail on error.** All shell scripts use `set -euo pipefail` (or `set -eu` for POSIX sh). Functions return 0 on success, non-zero on failure. Avoid `|| true` except in validation functions where warnings shouldn't block execution.

**Validation warns but doesn't block.** User-facing validation commands (like lock file checksum mismatches) should warn with actionable fix commands but never prevent the user from continuing. The validation philosophy is "inform, don't obstruct."

### Documentation Style

Documentation is split into two types with different purposes:

**1. Guides and Examples** - Help users accomplish tasks
- Use prose style with short, digestible paragraphs (2-4 sentences)
- Only use bullet points and numbered lists for step-by-step instructions
- Focus on practical workflows and common use cases
- Include runnable code examples
- No marketing language or superlatives
- Examples: CLAUDE.md, CONVENTIONS.md, workflow README files

**2. Reference Documentation** - Exhaustive explanations of all options
- Document every user-facing option, variable, method, and command
- Organized by component (environment variables, CLI commands, config options)
- Concise descriptions without fluff
- Include valid values, defaults, and constraints
- Examples: REFERENCE.md files for each plugin

**General writing rules:**
- Write concisely. Remove unnecessary words.
- No marketing language. Avoid terms like "powerful," "seamless," "robust," "flexible."
- Use active voice. "The script validates" not "Validation is performed."
- One concept per paragraph.
- Code examples should be runnable and realistic.

### Naming Standards

**Environment Variables:**
```
{PLATFORM}_{CATEGORY}_{DESCRIPTOR}

Examples:
- ANDROID_DEFAULT_DEVICE
- ANDROID_SDK_ROOT
- IOS_DEVELOPER_DIR
- ANDROID_BUILD_TOOLS_VERSION
```

**Shell Scripts:**
```
{platform}.sh       - Main CLI entry point (android.sh, ios.sh)
{feature}.sh        - Feature-specific scripts (devices.sh, avd.sh, env.sh)
lib.sh              - Shared utility functions
test-{feature}.sh   - Test scripts

Examples:
- android.sh
- devices.sh
- env.sh
- lib.sh
- test-devices.sh
```

**Shell Functions:**
```
{platform}_{category}_{action}

Examples:
- android_devices_list
- android_devices_create
- ios_get_developer_dir
- android_validate_lock_file
```

**Device Files:**
```
{descriptor}.json   - Device definition files

Examples:
- min.json          - Minimum supported version
- max.json          - Maximum/latest version
- pixel_api30.json  - Descriptive device name
```

**Lock Files:**
```
devices.lock        - Generated lock file (plain text, device:checksum format)
```

**Cache Files:**
```
.{feature}.cache    - Hidden cache files with descriptive names

Examples:
- .xcode_dev_dir.cache
- .shellenv.cache
```

### Directory Structure Standards

**Plugin Directory Layout:**
```
plugins/{platform}/
├── config/              # Template files copied to user projects
│   ├── devices/         # Default device definitions
│   └── *.yaml           # Process-compose test suites
├── scripts/             # Runtime scripts
│   ├── {platform}.sh    # Main CLI
│   ├── lib.sh           # Shared utilities
│   ├── env.sh           # Environment setup
│   └── {feature}.sh     # Feature scripts
├── plugin.json          # Plugin manifest
└── REFERENCE.md         # Complete API reference
```

**Example Project Layout:**
```
examples/{platform}/
├── devbox.d/
│   └── {platform}/
│       └── devices/     # User device definitions
│           ├── *.json
│           └── devices.lock
├── devbox.json          # Includes plugin
└── README.md            # Usage guide
```

**Test Directory Layout:**
```
plugins/tests/
├── {platform}/
│   ├── test-lib.sh           # Unit tests for lib.sh
│   ├── test-devices.sh       # Unit tests for devices.sh
│   ├── test-device-mgmt.sh   # Integration tests
│   └── test-validation.sh    # Validation tests
└── test-framework.sh         # Shared test utilities
```

### Process-Compose Standards

**File naming:**
```
process-compose-{suite}.yaml

Examples:
- process-compose-lint.yaml
- process-compose-unit-tests.yaml
- process-compose-e2e.yaml
```

**Process naming:**
```
{category}-{feature}

Examples:
- lint-android
- test-android-lib
- e2e-android
- summary
```

**Log locations:**
```
test-results/{suite-name}-logs

Examples:
- test-results/devbox-lint-logs
- test-results/android-repo-e2e-logs
```

**Always include a summary process:**
- Depends on all other processes with `process_completed` (not `process_completed_successfully`)
- Displays test results in clean, scannable format
- Lists log file locations for debugging

### Git Commit Standards

Commits should follow conventional commit format:

```
{type}({scope}): {description}

Examples:
- feat(android): add device sync command
- fix(ios): resolve Xcode path caching issue
- docs(contributing): add naming standards
- test(android): add device management tests
- refactor(react-native): simplify plugin composition
```

**Types:** feat, fix, docs, test, refactor, perf, chore

**Scopes:** android, ios, react-native, ci, docs, tests

## CI/CD

### Fast PR Checks (`pr-checks.yml`)
- Runs automatically on every PR
- Plugin validation and quick smoke tests
- ~15-30 minutes total
- Tests default devices only

### Full E2E Tests (`e2e-full.yml`)
- Manual trigger or weekly schedule
- Tests min/max platform versions:
  - Android: API 21 (min) to API 36 (max)
  - iOS: iOS 15.4 (min) to iOS 26.2 (max)
- ~45-60 minutes per platform
- Matrix execution for parallel testing

### Running CI Locally

```bash
# Requires act (GitHub Actions local runner)
# Install: devbox add act

# Run specific jobs
act -j android-plugin-tests
act -j ios-plugin-tests
act -j android-quick-smoke
act -j ios-quick-smoke

# Run full workflow
act -W .github/workflows/pr-checks.yml
```

## Configuration

Configuration for both Android and iOS plugins is now managed via environment variables defined in `plugin.json`. These env vars are converted to JSON at runtime for internal use.

### Android Plugin Environment Variables
- `ANDROID_DEFAULT_DEVICE` - Default emulator
- `ANDROID_DEVICES` - Devices to evaluate (comma-separated, empty = all)
- `ANDROID_APP_APK` - APK path/glob for installation
- `ANDROID_BUILD_TOOLS_VERSION` - Build tools version
- `ANDROID_LOCAL_SDK` - Use local SDK instead of Nix (0/1)

### iOS Plugin Environment Variables
- `IOS_DEFAULT_DEVICE` - Default simulator
- `IOS_DEVICES` - Devices to evaluate (comma-separated, empty = all)
- `IOS_APP_PROJECT` - Xcode project path
- `IOS_APP_SCHEME` - Xcode build scheme
- `IOS_APP_ARTIFACT` - App bundle path/glob
- `IOS_DOWNLOAD_RUNTIME` - Auto-download runtimes (0/1)

## Important Implementation Notes

### Android SDK via Nix Flake
- The Android SDK is composed via Nix flake at `devbox.d/android/flake.nix`
- Flake outputs: `android-sdk`, `android-sdk-full`, `android-sdk-preview`
- Nix handles flake evaluation caching internally (fast after first evaluation)
- Lock file limits which API versions are evaluated (optimization for CI)

### iOS Xcode Discovery
- Multiple strategies: `IOS_DEVELOPER_DIR` env var → `xcode-select -p` → `/Applications/Xcode*.app`
- Selects latest Xcode by version number
- Path cached in `.xcode_dev_dir.cache` (1-hour TTL)

### Validation Philosophy
- Validation warnings never block execution
- Warn with actionable fix commands
- Skip validation in CI or when tools are missing
- Examples: lock file checksum mismatches, missing SDK paths

### Script Safety
- All scripts use `set -euo pipefail` (or `set -eu` for POSIX)
- Functions return 0 on success, non-zero on failure
- Validation functions use `|| true` to avoid blocking

## References

For complete command and configuration references, see:
- `plugins/android/REFERENCE.md`
- `plugins/ios/REFERENCE.md`
- `plugins/react-native/REFERENCE.md`
- `plugins/CONVENTIONS.md`
- `.github/workflows/README.md`
