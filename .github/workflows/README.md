# GitHub Actions Workflows

This directory contains comprehensive CI/CD workflows using **orchestrated testing** powered by process-compose for the Devbox mobile plugins and example projects.

## What's New: Orchestrated Testing 🚀

All workflows now use process-compose orchestration with:
- ✅ **Automatic status checks** - Boot verification, app deployment, process health
- ✅ **Concurrent execution** - Independent tests run in parallel
- ✅ **Configurable timeouts** - No infinite hangs (`BOOT_TIMEOUT`, `TEST_TIMEOUT`)
- ✅ **Better logging** - Per-process logs automatically uploaded to artifacts
- ✅ **Proper failure handling** - Dependent tasks skip on failure
- ✅ **Unified approach** - Consistent test methodology across platforms

## Workflows

### 1. PR Fast Checks (`pr-checks.yml`)

**Trigger**: Automatically runs on every PR and push to main

**Purpose**: Fast validation to catch issues early (~30-40 minutes)

**What it tests**:
- Shellcheck linting + GitHub workflow validation (orchestrated)
- Plugin unit tests with parallel execution (orchestrated)
- Device management functionality
- Cache functionality
- Quick smoke tests with automatic boot verification (orchestrated)

**Jobs**:

1. **lint-and-validate** (ubuntu-24.04, ~10 min)
   - Uses `devbox run test:lint` (orchestrated)
   - Shellcheck on all scripts (parallel)
   - GitHub workflow validation via `act`

2. **android-plugin-tests** (ubuntu-24.04, ~15 min)
   - Uses `devbox run test:android` (orchestrated)
   - All Android unit tests run in parallel
   - Automatic test parallelization

3. **ios-plugin-tests** (macos-15, ~15 min)
   - Uses `devbox run test:ios` (orchestrated)
   - All iOS unit tests run in parallel
   - Automatic test parallelization

4. **android-quick-smoke** (ubuntu-24.04 + KVM, ~30 min)
   - Uses `tests/e2e-android-orchestrated.sh`
   - Setup → Build → Boot (verified) → Deploy (verified) → Verify app running
   - Automatic status checks with 3-second polling

5. **ios-quick-smoke** (macos-15, ~20 min)
   - Uses `tests/e2e-ios-orchestrated.sh`
   - Setup → Build → Boot (verified) → Deploy (verified) → Verify app running
   - Automatic status checks with 3-second polling

6. **android-example-unit-tests**, **ios-unit-tests**, **react-native-unit-tests**
   - Traditional unit tests (independent of orchestration)

7. **status-check** - Aggregates results from all jobs

This workflow provides fast feedback with **improved reliability** through automatic verification at each stage.

---

### 2. Full E2E Tests (`e2e-full.yml`)

**Trigger**:
- Manual dispatch via GitHub Actions UI
- Weekly schedule (Mondays at 00:00 UTC)

**Purpose**: Comprehensive end-to-end testing with **orchestrated workflows** across min/max platform versions (~45-60 minutes per job)

**Platform Coverage**:

#### Android
- **Min**: API 21 (Android 5.0 Lollipop) on ubuntu-24.04
- **Max**: API 36 (Android 15) on ubuntu-24.04
- **Hardware Acceleration**: KVM enabled for performance
- **NEW**: Orchestrated with automatic boot verification

#### iOS
- **Min**: iOS 15.4 on macos-14 (first Apple Silicon macOS supporting iOS 15.4)
- **Max**: iOS 26.2 on macos-15 (latest macOS version)
- **NEW**: Orchestrated with automatic boot verification

#### React Native
- Tests both Android and iOS builds on min/max versions
- **NEW**: Unified job with platform matrix (was split before)
- **NEW**: Orchestrated with full status checking

**Jobs**:

1. **android-e2e** (ubuntu-24.04, ~45 min, matrix: min/max)
   - Uses `tests/e2e-android-orchestrated.sh`
   - Full workflow with status verification at each stage
   - Configurable timeouts: `BOOT_TIMEOUT=240`, `TEST_TIMEOUT=600`

2. **ios-e2e** (macos-14/15, ~45 min, matrix: min/max)
   - Uses `tests/e2e-ios-orchestrated.sh`
   - Full workflow with status verification at each stage
   - Configurable timeouts: `BOOT_TIMEOUT=180`, `TEST_TIMEOUT=600`

3. **react-native-e2e** (ubuntu/macos, ~60 min, matrix: android/ios × min/max)
   - Uses `tests/e2e-react-native-orchestrated.sh`
   - Unified job for both platforms
   - Conditional setup based on platform
   - Extended timeout: `TEST_TIMEOUT=900`

4. **e2e-summary** - Aggregates all results

**Features**:
- ✅ **Parallel execution** using matrix strategy
- ✅ **Selective execution** via workflow inputs
- ✅ **Orchestrated testing** with automatic status checks
- ✅ **Process-compose logs** uploaded on failure
- ✅ **Configurable timeouts** per test stage
- ✅ **Proper failure handling** with dependency chaining

## Running Tests Manually

### Run Full E2E Suite

1. Go to the **Actions** tab in GitHub
2. Select **Full E2E Tests** workflow
3. Click **Run workflow**
4. (Optional) Uncheck platforms you don't want to test
5. Click **Run workflow**

### Run Specific Tests

You can selectively run tests by toggling the inputs:
- `run_android`: Test Android native examples
- `run_ios`: Test iOS native examples
- `run_react_native`: Test React Native cross-platform example

## Test Matrix

### Android E2E
```yaml
- device: min (API 21) - Android 5.0
- device: max (API 36) - Android 15
```

### iOS E2E
```yaml
- device: min (iOS 15.4)
- device: max (iOS 26.2)
```

### React Native E2E
```yaml
- platform: android, device: min (API 21)
- platform: android, device: max (API 36)
- platform: ios, device: min (iOS 15.4)
- platform: ios, device: max (iOS 26.2)
```

## Device Configurations

Device configurations are stored in each example's `devbox.d/` directory:

```
devbox/examples/
├── android/devbox.d/android/devices/
│   ├── min.json  (API 21)
│   └── max.json  (API 36)
├── ios/devbox.d/ios/devices/
│   ├── min.json  (iOS 15.4)
│   └── max.json  (iOS 26.2)
└── react-native/devbox.d/
    ├── android/devices/
    │   ├── min.json
    │   └── max.json
    └── ios/devices/
        ├── min.json
        └── max.json
```

## Timeout Settings

- **PR Fast Checks**: 15-30 minutes per job
- **E2E Tests**: 45-60 minutes per job
- Includes buffer time for:
  - Emulator/simulator boot time
  - Dependency installation
  - Build processes
  - Test execution

## Concurrency

PR checks use concurrency groups to cancel outdated runs:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

This saves CI resources by cancelling superseded runs when new commits are pushed.

## Failure Handling

- `fail-fast: false` - Tests continue even if one matrix job fails
- Artifacts are uploaded on failure for debugging
- Summary jobs aggregate results and report overall status

## Debugging Failed Tests

When a test fails:

1. **Check the job logs** in the Actions tab
2. **Download artifacts** (uploaded automatically on failure):
   - **NEW**: Process-compose logs per process (setup, build, boot, deploy, verify)
   - Android: `/tmp/android-e2e-logs/`, build outputs
   - iOS: `/tmp/ios-e2e-logs/`, CoreSimulator logs
   - React Native: `/tmp/rn-e2e-logs/`, both platforms

3. **Examine orchestration logs**:
   ```bash
   # Download and extract artifact
   tar -xzf android-smoke-logs.tar.gz

   # View specific process logs
   cat /tmp/android-e2e-logs/android-emulator.log  # Boot process
   cat /tmp/android-e2e-logs/build-app.log         # Build output
   cat /tmp/android-e2e-logs/deploy-app.log        # Deployment
   ```

4. **Reproduce locally** using orchestrated tests:
   ```bash
   # Android E2E (with same timeouts as CI)
   cd examples/android
   BOOT_TIMEOUT=240 TEST_TIMEOUT=600 bash ../../tests/e2e-android-orchestrated.sh

   # With interactive TUI for debugging
   TEST_TUI=true BOOT_TIMEOUT=240 bash ../../tests/e2e-android-orchestrated.sh

   # iOS E2E
   cd examples/ios
   BOOT_TIMEOUT=180 TEST_TIMEOUT=600 bash ../../tests/e2e-ios-orchestrated.sh

   # Legacy approach (still works)
   cd examples/android
   EMU_HEADLESS=1 devbox run --pure start:emu min
   ```

### Common Failure Patterns

**Emulator boot timeout:**
```
[ERROR] android-emulator failed: readiness probe timeout after 240s
[INFO] deploy-app skipped: dependency android-emulator not healthy
```
→ Check `android-emulator.log`, may need increased `BOOT_TIMEOUT`

**Build failure:**
```
[ERROR] build-app failed: exit code 1
[INFO] deploy-app skipped: dependency build-app not completed successfully
```
→ Check `build-app.log` for compilation errors

**App deployment failure:**
```
[ERROR] deploy-app failed: readiness probe timeout after 60s
```
→ Check `deploy-app.log` for ADB/installation errors

## Cache Management

### Viewing Cache Usage
Check your repository's cache usage:
1. Go to **Settings** → **Actions** → **Caches**
2. View cache size and hit rates
3. Manually delete old caches if needed

### Cache Limits
- **Total size**: 10 GB per repository (soft limit)
- **Retention**: 7 days of inactivity
- **Eviction**: Oldest caches deleted first when limit reached

### Optimizing Cache Performance
- Caches are scoped to branch by default
- PR caches can restore from main branch caches
- Use `restore-keys` for fallback cache matching

## Adding New Test Cases

To add new test scenarios:

1. Update the test scripts in `devbox/plugins/tests/`
2. Add new jobs to `pr-checks.yml` for fast validation
3. Add new matrix entries to `e2e-full.yml` for platform coverage
4. Update this README with the new test coverage

## Runner Requirements

### Android Tests
- **OS**: `ubuntu-24.04` (with KVM hardware acceleration enabled)
- **Disk Space**: ~20GB per job (emulator images, build artifacts)
- **Memory**: 7GB+ (default for GitHub-hosted Ubuntu runners)
- **Cost**: ~$0.008/minute (standard Linux runner pricing)

### iOS Tests
- **Min Version (iOS 15.4)**: `macos-14` (first Apple Silicon macOS runner supporting iOS 15.4)
- **Max Version (iOS 26.2)**: `macos-15` (latest macOS supporting iOS 26.2)
- **Disk Space**: ~30GB per job (simulator runtimes, build artifacts)
- **Memory**: 7GB+ (default for GitHub-hosted macOS runners)
- **Cost**: ~$0.08/minute (macOS runner pricing)

### Cost Optimization
By running Android tests on Ubuntu instead of macOS:
- **10x cost reduction** for Android tests (Linux vs macOS pricing)
- KVM hardware acceleration provides similar performance to macOS
- Only iOS tests require expensive macOS runners

## Caching Strategy

All workflows use comprehensive caching to speed up builds and reduce CI time:

### Devbox Cache
- **Action**: `jetify-com/devbox-install-action@v0.14.0`
- **Config**: `enable-cache: true`
- **Caches**: Nix store, devbox packages, and shell environments

### Gradle Cache (Android)
- **Paths**: `~/.gradle/caches`, `~/.gradle/wrapper`
- **Key**: Based on `*.gradle*` and `gradle-wrapper.properties` hashes
- **Speedup**: 2-5 minutes per build

### CocoaPods Cache (iOS)
- **Paths**: `~/.cocoapods/repos`, `~/Library/Caches/CocoaPods`
- **Key**: Based on `Podfile.lock` hash
- **Speedup**: 1-3 minutes per build

### Xcode Build Cache (iOS)
- **Paths**: `~/Library/Developer/Xcode/DerivedData`
- **Key**: Based on Xcode project/workspace hashes
- **Speedup**: 3-7 minutes per build

### Node.js/npm Cache (React Native)
- **Action**: `actions/setup-node@v4` with built-in caching
- **Config**: `cache: 'npm'`
- **Key**: Based on `package-lock.json` hash
- **Speedup**: 1-2 minutes per build

### Cache Benefits
- **First run**: Full build, caches are populated
- **Subsequent runs**: 30-50% faster builds from cache hits
- **Cache invalidation**: Automatic when dependency files change
