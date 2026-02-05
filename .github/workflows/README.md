# GitHub Actions Workflows

This directory contains comprehensive CI/CD workflows for testing the Devbox mobile plugins and example projects.

## Workflows

### 1. PR Fast Checks (`pr-checks.yml`)

**Trigger**: Automatically runs on every PR and push to main

**Purpose**: Fast validation to catch issues early (~15-30 minutes)

**What it tests**:
- Plugin validation tests (Android & iOS)
- Device management functionality
- Cache functionality
- Quick smoke tests on default devices

**Jobs**:
- `android-plugin-tests`: Android plugin unit tests (ubuntu-24.04)
- `ios-plugin-tests`: iOS plugin unit tests (macos-15)
- `android-quick-smoke`: Quick Android emulator lifecycle test (ubuntu-24.04 + KVM)
- `ios-quick-smoke`: Quick iOS simulator lifecycle test (macos-15)
- `status-check`: Aggregates results

This workflow is designed to be fast and provide quick feedback to developers.

---

### 2. Full E2E Tests (`e2e-full.yml`)

**Trigger**:
- Manual dispatch via GitHub Actions UI
- Weekly schedule (Mondays at 00:00 UTC)

**Purpose**: Comprehensive end-to-end testing across min/max platform versions (~45-60 minutes per job)

**Platform Coverage**:

#### Android
- **Min**: API 21 (Android 5.0 Lollipop) on ubuntu-24.04
- **Max**: API 36 (Android 15) on ubuntu-24.04
- **Hardware Acceleration**: KVM enabled for performance

#### iOS
- **Min**: iOS 15.4 on macos-14 (first Apple Silicon macOS supporting iOS 15.4)
- **Max**: iOS 26.2 on macos-15 (latest macOS version)

#### React Native
Tests both Android and iOS builds on min/max versions

**Jobs**:
- `android-e2e`: Matrix testing on min/max Android APIs
- `ios-e2e`: Matrix testing on min/max iOS versions
- `react-native-e2e`: Full stack testing for React Native apps
- `e2e-summary`: Aggregates all results

**Features**:
- Parallel execution using matrix strategy
- Selective execution via workflow inputs
- Artifact upload on failure for debugging
- Comprehensive logging

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
   - Android: Build outputs and logs
   - iOS: CoreSimulator logs
   - React Native: Both Android and iOS build outputs

3. **Reproduce locally** using the same commands:
   ```bash
   # Android example
   cd devbox/examples/android
   EMU_HEADLESS=1 devbox run --pure start-emu min

   # iOS example
   cd devbox/examples/ios
   SIM_HEADLESS=1 devbox run --pure start-sim min
   ```

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
