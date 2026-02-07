# Script Layering Architecture

The Android plugin scripts are organized into layers to prevent circular dependencies and maintain clear separation of concerns.

## Layer Rules

**Critical Rule**: Scripts can only source/depend on scripts from **earlier layers**, never from the same layer or later layers.

This prevents circular dependencies and makes the codebase easier to understand and maintain.

## Directory Structure

```
scripts/
├── lib/              # Layer 1: Pure Utilities
│   └── lib.sh
├── platform/         # Layer 2: Platform Setup
│   ├── core.sh
│   └── device_config.sh
├── domain/           # Layer 3: Domain Operations
│   ├── avd.sh
│   ├── avd-reset.sh
│   ├── emulator.sh
│   ├── deploy.sh
│   └── validate.sh
├── user/             # Layer 4: User CLI
│   ├── android.sh
│   └── devices.sh
└── init/             # Layer 5: Setup & Init
    └── setup.sh
```

## Layer Structure

```
Layer 1: lib/ - Pure Utilities
  ↓
Layer 2: platform/ - Platform Setup
  ↓
Layer 3: domain/ - Domain Operations
  ↓
Layer 4: user/ - User CLI
  ↓
Layer 5: init/ - Environment Init
```

## Layer 1: Pure Utilities

**File**: `lib.sh`

**Purpose**: Pure utility functions with no Android-specific logic.

**Functions**:
- String manipulation (`android_normalize_name`, `android_sanitize_avd_name`)
- Path resolution (`android_resolve_project_path`, `android_resolve_config_dir`)
- Checksums (`android_compute_devices_checksum`)
- Requirement checking (`android_require_tool`, `android_require_jq`)

**Dependencies**: None

## Layer 2: Platform Setup

**Files**: `core.sh`, `device_config.sh`

**Purpose**: SDK resolution, PATH setup, and device configuration utilities.

### core.sh
- SDK resolution (Nix flake evaluation, local SDK detection)
- PATH setup (`android_setup_path`)
- Environment variable setup (`android_setup_sdk_environment`)
- Debug utilities

### device_config.sh
- Device file discovery and selection
- Device definition loading and parsing
- Device filtering by ANDROID_DEVICES env var

**Dependencies**: Layer 1 only

## Layer 3: Domain Operations

**Directory**: `domain/`

**Files**:
- `domain/avd.sh` - AVD creation, deletion, and management
- `domain/avd-reset.sh` - AVD reset operations
- `domain/emulator.sh` - Emulator lifecycle (start/stop)
- `domain/deploy.sh` - App deployment to emulators
- `domain/validate.sh` - Environment validation

**Purpose**: Internal domain logic for Android operations. These scripts are not meant to be called directly by users.

**Critical Rule**: Scripts in this layer CANNOT source or call functions from other layer 3 scripts. If two layer 3 scripts need the same functionality, that functionality must be moved to layer 2 or layer 1.

**Why?** Layer 3 scripts are domain operations that should be atomic and independent. Orchestration of multiple layer 3 operations belongs in layer 4.

**Example - WRONG**:
```sh
# domain/emulator.sh calling domain/avd.sh - VIOLATES LAYER RULE
android_start_emulator() {
  android_setup_avds  # ❌ Calling another layer 3 function
  # ... start emulator
}
```

**Example - CORRECT**:
```sh
# android.sh (layer 4) orchestrates multiple layer 3 operations
android.sh emulator start) {
  . domain/avd.sh
  . domain/emulator.sh

  # Step 1: Setup AVDs
  android_setup_avds

  # Step 2: Start emulator
  android_start_emulator
}
```

**Dependencies**: Layers 1 & 2 only

## Layer 4: User CLI

**Files**: `android.sh`, `devices.sh`

**Purpose**: User-facing command-line interfaces.

### android.sh
Main CLI entry point with commands:
- `devices` - Delegate to devices.sh
- `config` - Configuration management
- `info` - SDK information display
- `emulator start|stop|reset` - Emulator operations
- `deploy` - App deployment

### devices.sh
Device management CLI:
- `list` - List device definitions
- `create` - Create device definition
- `update` - Update device definition
- `delete` - Delete device definition
- `eval` - Generate devices.lock
- `sync` - Sync AVDs with device definitions

**Purpose**: Orchestrate layer 3 operations and provide clean user interface.

**Dependencies**: Can source from layers 1, 2, and 3

## Layer 5: Setup & Init

**File**: `setup.sh`

**Purpose**: Dual-purpose initialization script run by devbox init hooks.

**Two execution modes**:

1. **Executed mode** (`bash setup.sh`): Config file generation
   - Generates `android.json` from environment variables for Nix flake evaluation
   - Generates `devices.lock` from device definitions
   - Makes scripts executable
   - Runs once on `devbox shell` startup

2. **Sourced mode** (`. setup.sh`): Environment initialization
   - Sources `platform/core.sh` which handles SDK resolution and PATH setup
   - `core.sh` automatically sources `lib/lib.sh` as a dependency
   - Runs validation (non-blocking)
   - Optionally displays SDK summary
   - Runs on every shell startup

The script detects its execution mode and behaves accordingly. In sourced mode, it delegates the heavy lifting to `core.sh` (layer 2).

**Dependencies**: Sources layer 2 (`platform/core.sh`), which sources layer 1 (`lib/lib.sh`)

## Dependency Graph

```
lib/lib.sh (layer 1)
  ↓
platform/core.sh (layer 2) - SDK resolution, PATH setup
platform/device_config.sh (layer 2) - Device configuration
  ↓
domain/avd.sh (layer 3) - AVD management
domain/avd-reset.sh (layer 3) - AVD reset
domain/emulator.sh (layer 3) - Emulator lifecycle
domain/deploy.sh (layer 3) - App deployment
domain/validate.sh (layer 3) - Validation
  ↓
user/android.sh (layer 4) - Main CLI
user/devices.sh (layer 4) - Device management CLI
  ↓
init/setup.sh (layer 5) - Config generation & env init
  (sources core.sh when sourced)
```

## Adding New Scripts

When adding a new script, ask:

1. **What does this script depend on?**
   - If it only needs utilities → Layer 1
   - If it needs SDK/platform setup → Layer 2
   - If it performs domain operations → Layer 3
   - If it's a user-facing CLI → Layer 4
   - If it's environment initialization → Layer 5

2. **Can I avoid same-layer dependencies?**
   - If a layer 3 script needs another layer 3 script, consider:
     - Moving shared logic to layer 2
     - Having layer 4 source both scripts
     - Splitting into smaller, focused scripts

3. **Is this script internal or user-facing?**
   - Internal domain operations → `domain/` directory
   - User-facing CLI → `user/` directory

## Testing Layer Violations

To check for layer violations:

```bash
# Layer 3 scripts should not source other layer 3 scripts
grep -r "ANDROID_SCRIPTS_DIR}/domain" domain/

# Should return no matches (except in comments/notes)
```

## Benefits

1. **No circular dependencies** - Impossible by design
2. **Clear structure** - Easy to understand what depends on what
3. **Easier testing** - Lower layers can be tested independently
4. **Better maintainability** - Changes in one layer have predictable impact
5. **Forced modularity** - Encourages small, focused scripts
