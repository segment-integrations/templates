# Testing Workflows Locally

This guide explains how to test GitHub Actions workflows locally using `act`.

## Prerequisites

### Install act

**Via devbox** (recommended):
```bash
devbox shell
```

**Via Homebrew** (macOS/Linux):
```bash
brew install act
```

**Via Docker**:
```bash
# act is available as a container
docker pull ghcr.io/catthehacker/ubuntu:act-latest
```

## Usage

### 1. List Available Workflows

```bash
ls .github/workflows/*.yml
```

Output:
- `e2e-full.yml` - Full E2E test suite
- `pr-checks.yml` - Fast PR validation checks

### 2. List Jobs in a Workflow

```bash
act -W .github/workflows/pr-checks.yml -l
```

This shows all jobs defined in the workflow.

### 3. Validate Workflow Syntax

```bash
# Dry run to check syntax
act -W .github/workflows/pr-checks.yml -n
```

### 4. Run Specific Jobs

#### Using the helper script:
```bash
./.github/workflows/test-locally.sh pr-checks android-plugin-tests
```

#### Using act directly:
```bash
# Run Android plugin tests
act -W .github/workflows/pr-checks.yml -j android-plugin-tests

# Run with verbose output
act -W .github/workflows/pr-checks.yml -j android-plugin-tests -v

# Run with specific platform
act -W .github/workflows/pr-checks.yml -j android-plugin-tests \
  --container-architecture linux/amd64
```

## Testing Android Workflows

### Important: Docker and KVM

Android emulator tests require KVM hardware acceleration, which is challenging to set up in Docker containers. For local testing:

**Option 1: Test validation only**
```bash
# Test Android plugin validation (no emulator needed)
act -W .github/workflows/pr-checks.yml -j android-plugin-tests
```

**Option 2: Test on actual CI**
```bash
# Push to a test branch to trigger CI
git checkout -b test/workflows
git push origin test/workflows
```

**Option 3: Use GitHub's local runner**
Follow GitHub's guide: https://docs.github.com/en/actions/hosting-your-own-runners

### Testing Without Emulator

To test the workflow logic without actually running emulators:

```bash
# Dry run to validate workflow syntax and job dependencies
act -W .github/workflows/e2e-full.yml -n

# List all jobs in the E2E workflow
act -W .github/workflows/e2e-full.yml -l
```

## Testing iOS Workflows

iOS simulator workflows require macOS and cannot run in Docker containers. For local testing:

**Option 1: Run iOS tests natively**
```bash
# Must be on macOS
cd examples/ios
devbox shell
SIM_HEADLESS=1 devbox run --pure start-sim min
```

**Option 2: Validate workflow syntax**
```bash
# Check for YAML errors and job configuration
act -W .github/workflows/pr-checks.yml -j ios-plugin-tests -n
```

## Testing React Native Workflows

React Native workflows combine Android and iOS. Test them separately:

```bash
# Test Android part of React Native workflow
act -W .github/workflows/e2e-full.yml -j react-native-e2e \
  --matrix platform:android

# Validate iOS part (syntax only on non-macOS)
act -W .github/workflows/e2e-full.yml -j react-native-e2e -n
```

## Common act Options

```bash
# Dry run (validate syntax only)
act -n

# Verbose output
act -v

# Use specific workflow file
act -W .github/workflows/pr-checks.yml

# Run specific job
act -j job-name

# List available workflows
act -l

# Use specific runner image
act -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04

# Pass secrets
act -s GITHUB_TOKEN=your_token

# Bind mount local directory
act --bind
```

## Workflow-Specific Testing

### PR Checks Workflow

Test individual jobs from the PR checks:

```bash
# Android plugin tests (Ubuntu)
act -W .github/workflows/pr-checks.yml -j android-plugin-tests

# iOS plugin tests (macOS only)
# Run on actual macOS machine:
act -W .github/workflows/pr-checks.yml -j ios-plugin-tests

# Validate status check aggregation
act -W .github/workflows/pr-checks.yml -j status-check
```

### E2E Full Workflow

```bash
# Test Android E2E (with matrix)
act workflow_dispatch -W .github/workflows/e2e-full.yml \
  -j android-e2e \
  --matrix device:min

# Validate iOS E2E syntax
act workflow_dispatch -W .github/workflows/e2e-full.yml \
  -j ios-e2e -n

# Test summary job
act workflow_dispatch -W .github/workflows/e2e-full.yml \
  -j e2e-summary
```

## Troubleshooting

### act doesn't find workflows
```bash
# Ensure you're in the repository root
cd /path/to/templates
act -l
```

### Docker daemon not running
```bash
# Start Docker Desktop or Docker daemon
sudo systemctl start docker  # Linux
open -a Docker              # macOS
```

### KVM not available in container
This is expected. KVM passthrough to Docker is complex and not recommended. Instead:
- Run validation tests that don't need emulators
- Test on actual CI for emulator-based tests
- Use native devbox commands for local emulator testing

### Out of memory errors
```bash
# Increase Docker memory limit in Docker Desktop settings
# Or use smaller test matrix
act -j android-plugin-tests  # Run one job at a time
```

## CI/CD Best Practices

1. **Test workflow syntax** with `act -n` before pushing
2. **Run validation jobs** locally when possible
3. **Use actual CI** for full emulator/simulator tests
4. **Check job dependencies** with `act -l` to see execution order
5. **Iterate quickly** by testing specific jobs instead of full workflows

## Resources

- [act Documentation](https://github.com/nektos/act)
- [GitHub Actions Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Runner Images](https://github.com/catthehacker/docker_images)
