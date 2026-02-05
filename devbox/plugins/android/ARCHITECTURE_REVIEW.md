# Android Plugin Scripts Architecture Review

## Executive Summary

The Android plugin scripts are **functional and well-documented**, but suffer from:
- ❌ **DRY violations** (code duplication across scripts)
- ❌ **Single Responsibility violations** (functions doing too much)
- ⚠️ **High complexity** in core orchestration functions
- ⚠️ **Large file sizes** (avd.sh at 717 lines)
- ✅ **Good separation** between CLI and library scripts
- ✅ **Consistent naming** and guard patterns

**Overall Grade: C+**

While the scripts work reliably, refactoring would significantly improve maintainability, testability, and extensibility.

---

## Detailed Analysis

### 1. DRY (Don't Repeat Yourself) Violations

#### 🔴 CRITICAL: Checksum Computation Duplication

**Issue:** Identical checksum logic appears in 2 files

**Location:**
- `devices.sh:277-284` (in `eval` command)
- `validate.sh:14-23` (in `android_validate_lock_file()`)

**Code:**
```bash
# Duplicated in both files
if command -v sha256sum >/dev/null 2>&1; then
  checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
  checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
else
  checksum=""
fi
```

**Impact:**
- Changes to checksum algorithm require updates in 2 places
- Increased risk of inconsistency
- Harder to add new checksum tools

**Recommendation:**
```bash
# Add to lib.sh
android_compute_devices_checksum() {
  devices_dir="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | shasum -a 256 | cut -d' ' -f1
  else
    return 1
  fi
}
```

---

#### 🔴 CRITICAL: Config Path Resolution Duplication

**Issue:** Path resolution pattern repeated across scripts with slight variations

**Locations:**
- `env.sh:63-81` (`load_android_config`)
- `env.sh:125-140` (`resolve_flake_sdk_root`)
- `avd.sh:171-197` (`android_devices_dir`)

**Pattern (repeated 3+ times):**
```bash
if [ -n "${ANDROID_CONFIG_DIR:-}" ] && [ -f "${ANDROID_CONFIG_DIR}/android.json" ]; then
  config_path="${ANDROID_CONFIG_DIR}/android.json"
elif [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -f "${DEVBOX_PROJECT_ROOT}/devbox.d/android/android.json" ]; then
  config_path="${DEVBOX_PROJECT_ROOT}/devbox.d/android/android.json"
elif [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -f "${DEVBOX_PROJECT_DIR}/devbox.d/android/android.json" ]; then
  config_path="${DEVBOX_PROJECT_DIR}/devbox.d/android/android.json"
elif [ -n "${DEVBOX_WD:-}" ] && [ -f "${DEVBOX_WD}/devbox.d/android/android.json" ]; then
  config_path="${DEVBOX_WD}/devbox.d/android/android.json"
else
  config_path="./devbox.d/android/android.json"
fi
```

**Impact:**
- 19 occurrences of DEVBOX_* variable checks across scripts
- Hard to add new fallback locations
- Inconsistent behavior if one script is updated

**Recommendation:**
```bash
# Add to lib.sh
android_resolve_project_path() {
  subpath="${1:-devbox.d/android}"
  filename="${2:-}"

  for base_var in ANDROID_CONFIG_DIR DEVBOX_PROJECT_ROOT DEVBOX_PROJECT_DIR DEVBOX_WD; do
    base="$(eval "printf '%s' \"\${$base_var:-}\"")"
    if [ -n "$base" ]; then
      candidate="${base%/}/${subpath#/}"
      [ -n "$filename" ] && candidate="${candidate%/}/${filename}"
      if [ -e "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done

  # Fallback to current directory
  candidate="./${subpath#/}"
  [ -n "$filename" ] && candidate="${candidate%/}/${filename}"
  printf '%s\n' "$candidate"
}

# Usage
config_path="$(android_resolve_project_path "devbox.d/android" "android.json")"
devices_dir="$(android_resolve_project_path "devbox.d/android/devices")"
flake_path="$(android_resolve_project_path "devbox.d/android")"
```

**Benefit:** Single source of truth for all path resolution

---

#### 🟡 MODERATE: JQ Requirement Check Duplication

**Issue:** `require_jq()` function defined identically in 2 files

**Locations:**
- `android.sh:32-37`
- `devices.sh:43-48`

**Code:**
```bash
require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    exit 1
  fi
}
```

**Recommendation:** Move to `lib.sh` as `android_require_jq()` for consistency with other requirement functions

---

#### 🟡 MODERATE: Device File Resolution Logic

**Issue:** Similar logic for finding device files/names appears in multiple places

**Locations:**
- `devices.sh:50-68` (`resolve_device_file`)
- `avd.sh:207-224` (`android_resolve_device_name`)
- `avd.sh:226-238` (`android_select_device_files`)

**These could be consolidated into a single, more flexible function**

---

### 2. Single Responsibility Principle Violations

#### 🔴 CRITICAL: `android_setup()` Does Too Much (142 lines)

**Location:** `avd.sh:240-381`

**Current Responsibilities:**
1. ✓ Detect/validate SDK root
2. ✓ Export ANDROID_HOME
3. ✓ Require tools (avdmanager, emulator, jq)
4. ✓ Resolve Java home
5. ✓ Find devices directory
6. ✓ Read device definition files
7. ✓ Parse device JSON
8. ✓ Resolve device hardware profiles
9. ✓ Pick system images by ABI
10. ✓ Create AVDs
11. ✓ Build target list with complex string manipulation
12. ✓ Handle IFS manipulation for parsing

**Problems:**
- Mixing validation, configuration, parsing, and execution
- Hard to test individual components
- Difficult to reuse parts in other contexts
- Complex nested loops make it hard to follow

**Recommendation - Split into smaller functions:**

```bash
# New structure
android_setup() {
  android_validate_environment
  devices_dir="$(android_get_devices_dir)"
  device_specs="$(android_load_device_specs "$devices_dir")"
  android_create_avds_from_specs "$device_specs"
}

android_validate_environment() {
  # SDK, tools, Java checks only
}

android_get_devices_dir() {
  # Path resolution only
}

android_load_device_specs() {
  # Read and parse device files, build data structure
}

android_create_avds_from_specs() {
  # Iterate specs, resolve images, create AVDs
}
```

**Benefit:**
- Each function < 30 lines
- Testable in isolation
- Reusable components
- Clear data flow

---

#### 🔴 CRITICAL: `android_run_app()` Does Too Much (82 lines)

**Location:** `avd.sh:547-628`

**Current Responsibilities:**
1. ✓ Resolve device choice
2. ✓ Run device evaluation
3. ✓ Start emulator
4. ✓ Resolve project root
5. ✓ Build project
6. ✓ Resolve APK pattern
7. ✓ Find APK file
8. ✓ Resolve aapt tool
9. ✓ Parse APK badging
10. ✓ Extract package name
11. ✓ Extract activity name
12. ✓ Sanitize component strings
13. ✓ Install APK
14. ✓ Resolve activity component
15. ✓ Launch app
16. ✓ Verify app process

**Problems:**
- Orchestration + implementation mixed
- Difficult to test APK parsing separately
- Hard to support alternative launch methods
- Component resolution logic is duplicated/complex (lines 596-620)

**Recommendation - Split into pipeline:**

```bash
android_run_app() {
  device="$(android_resolve_target_device "${1:-}")"
  android_start "$device"

  project_root="$(android_get_project_root)"
  android_run_build "$project_root"

  apk_path="$(android_find_built_apk "$project_root")"
  app_metadata="$(android_parse_apk_metadata "$apk_path")"

  android_install_apk "$apk_path"
  android_launch_app "$app_metadata"
}

android_parse_apk_metadata() {
  # Extract package, activity using aapt
  # Return JSON or key=value format
}

android_launch_app() {
  # Component resolution + launch logic only
}
```

---

#### 🟡 MODERATE: `env.sh` Has Multiple Concerns

**Location:** `env.sh` (363 lines)

**Current Responsibilities:**
1. Define debug utilities
2. Define requirement utilities
3. Load configuration from JSON
4. Resolve SDK via Nix flake
5. Detect SDK from tools
6. Determine SDK preference order
7. Set all environment variables
8. Configure PATH
9. Source validation
10. Print summary

**Problem:** Hard to understand what env.sh's primary job is

**Recommendation:** Consider splitting:
- `android-debug.sh` - Debug utilities
- `android-sdk.sh` - SDK resolution logic
- `env.sh` - Main environment orchestrator (sources others)

---

### 3. Organizational Issues

#### 🔴 CRITICAL: `avd.sh` is Too Large (717 lines)

**Location:** `avd.sh`

**Current Contents:**
- Java resolution (18 lines)
- AVD checking (4 lines)
- Device resolution (45 lines)
- Image picking (37 lines)
- AVD creation (13 lines)
- Path utilities (28 lines)
- Device file utilities (40 lines)
- Main setup orchestration (142 lines)
- Emulator lifecycle (70 lines)
- App building (7 lines)
- APK resolution (28 lines)
- AAPT resolution (21 lines)
- App deployment (82 lines)
- State reset (87 lines)

**Problem:** Single file with 5+ distinct concerns

**Recommendation - Split into multiple files:**

```
avd-mgmt.sh       # AVD creation, device resolution, image picking
emulator.sh       # Start, stop, service lifecycle
app-deploy.sh     # Build, APK handling, installation, launch
android-reset.sh  # State reset logic
path-utils.sh     # Path resolution utilities (or add to lib.sh)
```

**Usage:**
```bash
# Other scripts source what they need
. "$script_dir/avd-mgmt.sh"
. "$script_dir/emulator.sh"
. "$script_dir/app-deploy.sh"
```

---

#### 🟡 MODERATE: Unclear Separation of Concerns

**Current structure:**
```
lib.sh       - String utilities (28 lines) ← Too small for dedicated file
env.sh       - Everything environment (363 lines) ← Too large
avd.sh       - Everything AVD/emulator (717 lines) ← Way too large
validate.sh  - Validation (38 lines) ← Good size
```

**Better structure:**
```
core/
  lib.sh              - Common utilities (path resolution, checksums, string utils)
  env.sh              - Environment orchestrator (sources others)
  sdk.sh              - SDK resolution logic
  debug.sh            - Debug utilities
  validate.sh         - Validation functions

avd/
  device.sh           - Device definition handling
  image.sh            - System image selection
  avd-create.sh       - AVD creation

emulator/
  lifecycle.sh        - Start, stop, service management

app/
  build.sh            - Build orchestration
  deploy.sh           - APK installation and launch

cli/
  android.sh          - Main CLI (unchanged)
  devices.sh          - Device management CLI (unchanged)
```

---

### 4. Complexity Reduction Opportunities

#### 🔴 CRITICAL: Complex IFS Manipulation

**Location:** `avd.sh:306-374`

**Current code:**
```bash
ifs_backup="$IFS"
IFS="$(printf '\n')"
for target in $TARGETS; do
  IFS='|' read -r api tag device preferred_abi name_override <<TARGET_EOF
$target
TARGET_EOF
  IFS="$(printf '\n')"
  # ... processing ...
done
IFS="$ifs_backup"
```

**Problem:**
- Fragile state management
- Easy to break with nested loops
- Hard to debug

**Recommendation - Use arrays or structured data:**

```bash
# Option 1: Use jq to build JSON structure
device_specs="$(android_load_device_specs "$devices_dir")"
# Returns JSON array: [{"api":28,"tag":"google_apis","device":"pixel",...}]

# Then iterate with jq
echo "$device_specs" | jq -c '.[]' | while read -r spec; do
  api="$(echo "$spec" | jq -r '.api')"
  tag="$(echo "$spec" | jq -r '.tag')"
  device="$(echo "$spec" | jq -r '.device')"
  # ... process ...
done
```

**OR**

```bash
# Option 2: Use functions returning one value at a time
android_for_each_device_spec() {
  callback="$1"
  devices_dir="$2"

  for device_file in $(android_device_files "$devices_dir"); do
    "$callback" "$device_file"
  done
}

process_device_file() {
  device_file="$1"
  api="$(jq -r '.api' "$device_file")"
  # ... process directly from file ...
}

android_for_each_device_spec process_device_file "$devices_dir"
```

---

#### 🟡 MODERATE: Component Resolution Has Duplicate Logic

**Location:** `avd.sh:596-620`

**Current code has component resolution logic twice:**
- Lines 596-610: Try to resolve via `cmd package resolve-activity`
- Lines 614-620: Duplicate case statement for activity name formatting

**Recommendation - Single resolution function:**

```bash
android_resolve_launch_component() {
  app_id="$1"
  activity="$2"
  serial="$3"

  # Try device resolution first
  component="$(adb -s "$serial" shell cmd package resolve-activity --brief "$app_id" 2>/dev/null | tr -d '\r' | tail -n1 | awk '{print $1}')"

  # Fallback to manual construction
  if [ -z "$component" ] || [ "${component#*/}" = "$component" ]; then
    case "$activity" in
      */*) component="$activity" ;;
      .*) component="${app_id}/${activity}" ;;
      *) component="${app_id}/${activity}" ;;
    esac
  fi

  printf '%s\n' "$component"
}
```

---

#### 🟡 MODERATE: Nested Conditionals in `pick_image()`

**Location:** `avd.sh:108-144`

**Current structure:**
```bash
pick_image() {
  # Nested: if preferred_abi → else case host_arch
  # Then: for loop with if debug → else
  # Then: if -d path check
}
```

**Recommendation - Extract candidate selection:**

```bash
android_get_abi_candidates() {
  preferred_abi="$1"
  host_arch="${2:-$(uname -m)}"

  if [ -n "$preferred_abi" ]; then
    printf '%s' "$preferred_abi"
    return
  fi

  case "$host_arch" in
    arm64|aarch64) printf '%s' "arm64-v8a x86_64 x86" ;;
    *) printf '%s' "x86_64 x86 arm64-v8a" ;;
  esac
}

pick_image() {
  api="$1"
  tag="$2"
  preferred_abi="$3"

  candidates="$(android_get_abi_candidates "$preferred_abi")"

  for abi in $candidates; do
    path="${ANDROID_SDK_ROOT}/system-images/android-${api}/${tag}/${abi}"
    android_debug_log "Checking ABI path: $path"
    [ -d "$path" ] && printf '%s\n' "system-images;android-${api};${tag};${abi}" && return 0
  done

  return 1
}
```

---

### 5. What's Done Well ✅

#### Good Practices to Maintain:

1. **Consistent Naming Convention**
   - All functions prefixed with `android_`
   - Clear, descriptive names

2. **Sourcing Guards**
   - Scripts that must be sourced have proper guards
   - PID-based duplicate sourcing prevention

3. **Debug Logging**
   - Consistent `android_debug_enabled()` checks
   - Useful debug output

4. **Non-Blocking Validation**
   - Validation warns but doesn't fail
   - Good for developer experience

5. **Clear CLI Interface**
   - `android.sh` and `devices.sh` have clean command structure
   - Good separation between CLI and library code

6. **Environment Variable Namespacing**
   - All variables use `ANDROID_` prefix
   - No conflicts with system variables

---

## Prioritized Refactoring Recommendations

### Phase 1: Critical DRY Violations (Low Risk, High Value)
**Effort:** 4-8 hours
**Risk:** Low (additive changes)

1. ✅ Add `android_compute_devices_checksum()` to `lib.sh`
2. ✅ Add `android_resolve_project_path()` to `lib.sh`
3. ✅ Update all call sites to use new functions
4. ✅ Add `android_require_jq()` to `lib.sh`

**Expected Impact:**
- 50+ lines of duplicate code eliminated
- Easier to maintain and extend
- Consistent behavior across all scripts

---

### Phase 2: Split Large Files (Medium Risk, High Value)
**Effort:** 8-16 hours
**Risk:** Medium (requires testing)

1. ✅ Split `avd.sh` into:
   - `avd-mgmt.sh` (AVD operations)
   - `emulator.sh` (lifecycle)
   - `app-deploy.sh` (deployment)
   - `android-reset.sh` (state reset)

2. ✅ Update scripts that source `avd.sh` to source new files

**Expected Impact:**
- Clearer code organization
- Easier to find relevant functions
- Reduced cognitive load

---

### Phase 3: Refactor Complex Functions (Higher Risk, High Value)
**Effort:** 16-24 hours
**Risk:** High (requires extensive testing)

1. ✅ Refactor `android_setup()` into smaller functions
2. ✅ Refactor `android_run_app()` into pipeline
3. ✅ Eliminate IFS manipulation with structured data approach
4. ✅ Consolidate component resolution logic

**Expected Impact:**
- More testable code
- Easier to extend
- Reduced bug surface area

---

### Phase 4: Organizational Restructure (Highest Risk, Medium Value)
**Effort:** 24-40 hours
**Risk:** Very High (requires migration strategy)

1. ✅ Restructure into `core/`, `avd/`, `emulator/`, `app/`, `cli/` directories
2. ✅ Update all sourcing paths
3. ✅ Update plugin.json
4. ✅ Provide migration guide

**Expected Impact:**
- Clear architectural boundaries
- Scalable organization for future features
- Easier onboarding for contributors

---

## Testing Recommendations

Currently there's **no obvious way to test** functions in isolation because:
- Functions are tightly coupled
- Heavy reliance on side effects and global state
- No dependency injection

**Recommendations:**

1. **Add test utilities to** `devbox/plugins/tests/`:
```bash
tests/
  android/
    unit/
      test-lib.sh              # Test lib.sh functions
      test-path-resolution.sh  # Test path utilities
      test-checksum.sh         # Test checksum function
    integration/
      test-device-management.sh
      test-avd-creation.sh
```

2. **Make functions more testable:**
```bash
# Bad: Hard to test (reads from filesystem, uses globals)
android_load_config() {
  config_path="${ANDROID_CONFIG_DIR}/android.json"
  jq -r '...' "$config_path"
}

# Good: Easy to test (takes path parameter)
android_load_config() {
  config_path="${1:-}"
  [ -f "$config_path" ] || return 1
  jq -r '...' "$config_path"
}
```

3. **Use test fixtures:**
```bash
tests/fixtures/
  android.json
  devices/
    test-min.json
    test-max.json
```

---

## Metrics Summary

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Largest file size | 717 lines | <300 lines | 🔴 Needs work |
| Longest function | 142 lines | <50 lines | 🔴 Needs work |
| Code duplication | High (3+ instances) | Minimal | 🔴 Needs work |
| Functions per file | 23 (avd.sh) | <10 | 🔴 Needs work |
| Test coverage | 0% | >60% | 🔴 Needs work |
| Cyclomatic complexity | High | Moderate | 🟡 Acceptable |
| Naming consistency | Excellent | Excellent | ✅ Good |
| Documentation | Good | Good | ✅ Good |

---

## Conclusion

The Android plugin scripts work well but have accumulated technical debt. The code would benefit from:

**Immediate Priority:**
- ✅ Extract duplicate code into `lib.sh`
- ✅ Split `avd.sh` into smaller files

**Medium Priority:**
- ✅ Refactor `android_setup()` and `android_run_app()`
- ✅ Eliminate complex IFS manipulation

**Long-term:**
- ✅ Restructure into logical directories
- ✅ Add unit tests for utility functions

**Keep doing:**
- ✅ Consistent naming conventions
- ✅ Good debug logging
- ✅ Non-blocking validation

The scripts demonstrate **good engineering practices** in naming, documentation, and error handling, but suffer from **organic growth** without periodic refactoring. A focused refactoring effort would significantly improve maintainability while preserving the existing functionality that users rely on.
