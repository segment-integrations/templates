#!/usr/bin/env bash
# Basic YAML validation for GitHub Actions workflows
set -euo pipefail

echo "GitHub Actions Workflow Validator"
echo "=================================="
echo ""

WORKFLOWS_DIR=".github/workflows"
ERRORS=0

# Check if workflows directory exists
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo "Error: $WORKFLOWS_DIR directory not found"
    exit 1
fi

# Find all workflow files
WORKFLOW_FILES=$(find "$WORKFLOWS_DIR" -name "*.yml" -o -name "*.yaml" | grep -v "test-locally.sh" | sort)

if [ -z "$WORKFLOW_FILES" ]; then
    echo "No workflow files found in $WORKFLOWS_DIR"
    exit 1
fi

echo "Found workflows:"
echo "$WORKFLOW_FILES" | sed 's/^/  - /'
echo ""

# Basic validation checks
for workflow in $WORKFLOW_FILES; do
    echo "Validating: $(basename "$workflow")"
    echo "---"

    # Check file is not empty
    if [ ! -s "$workflow" ]; then
        echo "  ✗ File is empty"
        ((ERRORS++))
        continue
    fi

    # Check for required top-level keys
    if ! grep -q "^name:" "$workflow"; then
        echo "  ✗ Missing 'name' field"
        ((ERRORS++))
    else
        NAME=$(grep "^name:" "$workflow" | head -1 | cut -d':' -f2- | xargs)
        echo "  ✓ Workflow name: $NAME"
    fi

    if ! grep -q "^on:" "$workflow"; then
        echo "  ✗ Missing 'on' trigger field"
        ((ERRORS++))
    else
        echo "  ✓ Has trigger configuration"
    fi

    if ! grep -q "^jobs:" "$workflow"; then
        echo "  ✗ Missing 'jobs' section"
        ((ERRORS++))
    else
        JOB_COUNT=$(grep -E "^  [a-z_-]+:" "$workflow" | wc -l | xargs)
        echo "  ✓ Has jobs section ($JOB_COUNT jobs)"
    fi

    # Check for common issues
    if grep -q "uses:.*@v[0-9]" "$workflow"; then
        PINNED_ACTIONS=$(grep -o "uses:.*@v[0-9][0-9.]*" "$workflow" | wc -l | xargs)
        echo "  ✓ Actions pinned to versions ($PINNED_ACTIONS)"
    fi

    # Check for timeout configuration
    if grep -q "timeout-minutes:" "$workflow"; then
        echo "  ✓ Has timeout configuration"
    else
        echo "  ⚠ Warning: No timeout-minutes set (jobs may run indefinitely)"
    fi

    # Check for caching
    if grep -q "actions/cache@" "$workflow"; then
        CACHE_COUNT=$(grep -o "actions/cache@" "$workflow" | wc -l | xargs)
        echo "  ✓ Uses caching ($CACHE_COUNT cache steps)"
    fi

    # Check for devbox-install-action version
    if grep -q "devbox-install-action@" "$workflow"; then
        DEVBOX_VERSION=$(grep -o "devbox-install-action@v[0-9.]*" "$workflow" | head -1 | cut -d'@' -f2)
        echo "  ✓ Devbox installer: $DEVBOX_VERSION"

        if grep -q "enable-cache: true" "$workflow"; then
            echo "  ✓ Devbox caching enabled"
        else
            echo "  ⚠ Warning: Devbox caching not enabled"
        fi
    fi

    # Check for Ubuntu with KVM
    if grep -q "ubuntu-" "$workflow" && grep -q "Enable KVM" "$workflow"; then
        echo "  ✓ Ubuntu runner with KVM configured"
    fi

    # Check for macOS version pinning
    if grep -q "runs-on:.*macos-" "$workflow"; then
        MACOS_VERSIONS=$(grep -o "macos-[0-9][0-9]*" "$workflow" | sort -u | xargs)
        echo "  ✓ macOS versions: $MACOS_VERSIONS"
    fi

    echo ""
done

# Summary
echo "=================================="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All workflows passed basic validation"
    exit 0
else
    echo "✗ Found $ERRORS error(s)"
    exit 1
fi
