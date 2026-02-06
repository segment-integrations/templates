# Process-Compose Dependency & Failure Handling

This document explains how process-compose handles dependencies, failures, and exit codes in our test orchestration.

## Dependency Conditions

Process-compose supports three dependency conditions:

### 1. `process_completed_successfully`
Process must exit with code 0 before dependents start.

```yaml
deploy-app:
  depends_on:
    build-app:
      condition: process_completed_successfully  # Must succeed
```

**Behavior:**
- ✅ Build exits 0 → Deploy starts
- ❌ Build exits 1 → Deploy SKIPS, test suite FAILS

### 2. `process_completed`
Process must finish (any exit code) before dependents start.

```yaml
cleanup:
  depends_on:
    test-suite:
      condition: process_completed  # Success or failure
```

**Behavior:**
- ✅ Test exits 0 → Cleanup runs
- ❌ Test exits 1 → Cleanup STILL runs (cleanup doesn't check exit code)

**Use case:** Cleanup operations that must run even if tests fail.

### 3. `process_healthy`
Process must be running AND pass readiness probe.

```yaml
deploy-app:
  depends_on:
    android-emulator:
      condition: process_healthy  # Must be running and ready
```

**Behavior:**
- ✅ Emulator boots and passes readiness → Deploy starts
- ❌ Emulator crashes → Deploy SKIPS
- ⏱️ Emulator times out → Deploy SKIPS

**Use case:** Long-running services (emulators, servers) that need health verification.

## Failure Scenarios

### Scenario 1: Emulator Fails to Start

**What happens:**

```yaml
# Example failure chain
setup-avd: ✅ SUCCESS (exit 0)
    ↓
android-emulator: ❌ FAIL (readiness timeout after 180s)
    ↓
deploy-app: ⏭️ SKIPPED (dependency not healthy)
    ↓
verify-app-running: ⏭️ SKIPPED (dependency not completed)
    ↓
cleanup: ✅ RUNS (uses process_completed, not _successfully)
    ↓
process-compose: ❌ EXIT 1
```

**Exit code:** `1` (failure)

**Output:**
```
[ERROR] android-emulator failed: readiness probe timeout after 180s
[INFO] deploy-app skipped: dependency android-emulator not healthy
[INFO] verify-app-running skipped: dependency deploy-app not completed
[INFO] cleanup running...
```

### Scenario 2: Build Fails

**What happens:**

```yaml
setup-avd: ✅ SUCCESS
    ↓
build-app: ❌ FAIL (gradle error, exit 1)
    ↓
android-emulator: ✅ STARTS (independent of build)
    ↓
deploy-app: ⏭️ SKIPPED (build-app dependency failed)
    ↓
process-compose: ❌ EXIT 1 (after stopping emulator)
```

**Exit code:** `1` (failure)

**Why emulator still starts:** No `depends_on` relationship with build-app, only with setup-avd.

### Scenario 3: App Deploy Fails

**What happens:**

```yaml
setup-avd: ✅ SUCCESS
build-app: ✅ SUCCESS
android-emulator: ✅ HEALTHY
    ↓
deploy-app: ❌ FAIL (adb install error, exit 1)
    ↓
verify-app-running: ⏭️ SKIPPED (deploy-app didn't complete successfully)
    ↓
cleanup: ✅ RUNS
    ↓
process-compose: ❌ EXIT 1
```

**Exit code:** `1` (failure)

### Scenario 4: All Succeed

**What happens:**

```yaml
setup-avd: ✅ SUCCESS
build-app: ✅ SUCCESS
android-emulator: ✅ HEALTHY
deploy-app: ✅ SUCCESS
verify-app-running: ✅ SUCCESS
cleanup: ✅ SUCCESS
    ↓
process-compose: ✅ EXIT 0
```

**Exit code:** `0` (success)

## Timeouts

Every process can fail due to timeout:

### Readiness Probe Timeout

```yaml
android-emulator:
  readiness_probe:
    timeout_seconds: 180  # FAIL if not ready within 180s
```

**Behavior:**
- After 180s, if probe still failing → Process FAILS
- Dependent processes SKIP
- Suite exits with code 1

### Liveness Probe Timeout

```yaml
android-emulator:
  liveness_probe:
    timeout_seconds: 5      # Each check times out after 5s
    failure_threshold: 3    # FAIL after 3 consecutive failures
```

**Behavior:**
- If 3 consecutive liveness checks fail → Process FAILS
- If `restart: "on_failure"`, process restarts (up to `max_restarts`)
- If restarts exhausted → Process FAILS permanently

### Command Timeout

Process-compose has no global command timeout by default. Use shell timeout:

```yaml
deploy-app:
  command: "timeout 60s devbox run --pure start:android"  # Fail after 60s
```

## Auto-Restart Behavior

```yaml
android-emulator:
  availability:
    restart: "on_failure"  # Restart if crashes or fails liveness
    max_restarts: 2        # Maximum 2 restart attempts
```

**Behavior:**

1. **First failure:** Restart attempt 1
2. **Second failure:** Restart attempt 2
3. **Third failure:** FAIL permanently, dependent processes SKIP

**What counts as failure:**
- Process exits with non-zero code
- Readiness probe times out
- Liveness probe fails `failure_threshold` times

**What triggers restart:**
- Process crash
- Liveness probe failure
- NOT readiness probe timeout (that's a permanent failure)

## Process-Compose Exit Codes

| Scenario | Exit Code |
|----------|-----------|
| All processes succeed | `0` |
| Any process fails | `1` |
| User interrupts (Ctrl+C) | `130` |
| Invalid config file | `1` |
| Process-compose error | `1` |

## Ensuring Cleanup Always Runs

Use `process_completed` (not `process_completed_successfully`):

```yaml
cleanup:
  command: "devbox run --pure stop:emu || true"
  depends_on:
    test-suite:
      condition: process_completed  # Runs on success OR failure
  availability:
    restart: "no"
```

**Important:** Add `|| true` to cleanup commands so they don't cause additional failures:

```yaml
cleanup:
  command: |
    devbox run --pure stop:emu || true
    rm -rf /tmp/test-artifacts || true
```

## Testing Failure Behavior

### Test emulator timeout

```bash
# Set unreasonably short timeout
BOOT_TIMEOUT=5 devbox run test:e2e:android

# Expected: Emulator fails readiness, deploy skips, exit code 1
```

### Test build failure

```bash
# Break a build file temporarily
cd examples/android
echo "invalid syntax" >> app/build.gradle.kts

devbox run test:e2e:android

# Expected: Build fails, deploy skips, exit code 1
# Cleanup should still run
```

### Test cleanup on failure

```bash
# Add echo to cleanup to verify it runs
# Edit process-compose-android.yaml temporarily:
cleanup:
  command: "echo 'CLEANUP RAN' && devbox run --pure stop:emu || true"

# Then cause a failure and check logs
BOOT_TIMEOUT=5 devbox run test:e2e:android 2>&1 | grep "CLEANUP RAN"
```

## CI Integration

Process-compose exit codes work perfectly with CI:

```yaml
# GitHub Actions
- name: Run tests
  run: devbox run test
  # CI sees exit code:
  #   0 = success (continue)
  #   1 = failure (fail the job)
```

## Common Patterns

### Pattern 1: Parallel with Any-Fail

```yaml
# All must succeed for dependents to run
lint-android:
  command: "shellcheck android/*.sh"

lint-ios:
  command: "shellcheck ios/*.sh"

tests:
  depends_on:
    lint-android:
      condition: process_completed_successfully
    lint-ios:
      condition: process_completed_successfully
```

**Behavior:** If either lint fails, tests SKIP.

### Pattern 2: Sequential Pipeline

```yaml
build:
  command: "gradle build"

test:
  depends_on:
    build:
      condition: process_completed_successfully

deploy:
  depends_on:
    test:
      condition: process_completed_successfully
```

**Behavior:** First failure breaks the chain, subsequent steps SKIP.

### Pattern 3: Cleanup Always Runs

```yaml
run-tests:
  command: "run-tests.sh"

cleanup:
  depends_on:
    run-tests:
      condition: process_completed  # Not _successfully
  command: "cleanup.sh || true"    # Never fail
```

**Behavior:** Cleanup runs whether tests pass or fail.

### Pattern 4: Health-Dependent Service

```yaml
database:
  command: "start-db.sh"
  readiness_probe:
    exec:
      command: "pg_isready"
    timeout_seconds: 30

app:
  depends_on:
    database:
      condition: process_healthy  # Wait for readiness
  command: "start-app.sh"
```

**Behavior:** App doesn't start until DB passes health check.

## Debugging Dependency Issues

### Check dependency graph

```bash
# Run with TUI to see visual dependency graph
TEST_TUI=true devbox run test:e2e:android
```

### View process execution order

```bash
# Check logs for what ran/skipped
ls -la /tmp/devbox-e2e-logs/
cat /tmp/devbox-e2e-logs/*.log | grep -E "START|SKIP|FAIL"
```

### Verify cleanup ran

```bash
# After a test run (success or failure)
tail /tmp/devbox-e2e-logs/cleanup.log

# Should see cleanup output even if tests failed
```

## Summary

✅ **Process-compose DOES:**
- Exit with code 1 on any failure
- Skip dependent processes when dependencies fail
- Support conditional dependencies
- Run cleanup processes even on failure
- Stop immediately on interrupt (Ctrl+C)
- Retry failed processes (if configured)

❌ **Process-compose DOES NOT:**
- Run forever waiting for stuck processes (timeouts handle this)
- Continue running skipped processes
- Hide failures (always returns non-zero on failure)
- Skip cleanup (if using `process_completed` condition)

**Key takeaway:** Process-compose has proper failure propagation. If any critical process fails, the suite exits with code 1, making it safe for CI/CD pipelines.
