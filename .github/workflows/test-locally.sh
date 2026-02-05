#!/usr/bin/env bash
# Test GitHub Actions workflows locally using act
# Usage: ./test-locally.sh [workflow] [job]
# Example: ./test-locally.sh pr-checks android-quick-smoke

set -euo pipefail

# Check if act is available
if ! command -v act &> /dev/null; then
    echo "Error: act is not installed"
    echo "Install via devbox: devbox shell"
    echo "Or install directly: https://github.com/nektos/act"
    exit 1
fi

# Default values
WORKFLOW="${1:-pr-checks}"
JOB="${2:-}"

# Validate workflow file exists
WORKFLOW_FILE=".github/workflows/${WORKFLOW}.yml"
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "Error: Workflow file not found: $WORKFLOW_FILE"
    echo "Available workflows:"
    ls .github/workflows/*.yml | xargs -n1 basename | sed 's/\.yml$//'
    exit 1
fi

echo "Testing workflow: $WORKFLOW_FILE"
echo "================================"
echo ""

# If job specified, run specific job
if [ -n "$JOB" ]; then
    echo "Running job: $JOB"
    echo ""
    act -W "$WORKFLOW_FILE" -j "$JOB" --container-architecture linux/amd64
else
    # List available jobs
    echo "Available jobs in $WORKFLOW:"
    act -W "$WORKFLOW_FILE" -l
    echo ""
    echo "To run a specific job, use: $0 $WORKFLOW <job-name>"
fi
