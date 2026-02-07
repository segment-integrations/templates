#!/usr/bin/env bash
set -euo pipefail

echo "Testing devbox-mcp tools..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_FRAMEWORK="${SCRIPT_DIR}/../../tests/test-framework.sh"
MCP_DIR="${SCRIPT_DIR}/.."

# Source test framework
. "${TEST_FRAMEWORK}"

# Check if node_modules are installed
if [ ! -d "${MCP_DIR}/node_modules" ]; then
  echo "Installing dependencies..."
  cd "${MCP_DIR}"
  npm install --silent
  cd - >/dev/null
fi

# Test 1: Server starts without errors
echo "Testing server startup (5 second timeout)..."
if timeout 5 node "${MCP_DIR}/src/index.js" </dev/null 2>&1 | grep -q "Devbox MCP server running"; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ Server starts successfully"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Server failed to start"
fi

# Test 2: Check tool schema definitions
echo "Checking tool schemas..."
server_content="$(cat "${MCP_DIR}/src/index.js")"

# devbox_run tool checks
if echo "$server_content" | grep -q 'name: "devbox_run"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_run tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_run tool not found"
fi

if echo "$server_content" | grep -q 'command:'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_run has command parameter"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_run missing command parameter"
fi

# devbox_list tool checks
if echo "$server_content" | grep -q 'name: "devbox_list"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_list tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_list tool not found"
fi

# devbox_add tool checks
if echo "$server_content" | grep -q 'name: "devbox_add"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_add tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_add tool not found"
fi

if echo "$server_content" | grep -q 'packages:'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_add has packages parameter"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_add missing packages parameter"
fi

# devbox_info tool checks
if echo "$server_content" | grep -q 'name: "devbox_info"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_info tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_info tool not found"
fi

# devbox_search tool checks
if echo "$server_content" | grep -q 'name: "devbox_search"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_search tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_search tool not found"
fi

# devbox_docs_search tool checks
if echo "$server_content" | grep -q 'name: "devbox_docs_search"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_search tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_search tool not found"
fi

if echo "$server_content" | grep -q 'maxResults'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_search has maxResults parameter"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_search missing maxResults parameter"
fi

# devbox_docs_list tool checks
if echo "$server_content" | grep -q 'name: "devbox_docs_list"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_list tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_list tool not found"
fi

# devbox_docs_read tool checks
if echo "$server_content" | grep -q 'name: "devbox_docs_read"'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_read tool defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_read tool not found"
fi

if echo "$server_content" | grep -q 'filePath'; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_read has filePath parameter"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_read missing filePath parameter"
fi

# Test 3: Check helper functions exist
echo "Checking helper functions..."
helper_functions="runDevbox ensureDocsRepo searchDocs listDocs readDoc"
for func in $helper_functions; do
  if echo "$server_content" | grep -q "function $func"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ $func helper function defined"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ $func helper function not found"
  fi
done

# Test 4: Check switch cases for all tools
echo "Checking tool handlers..."
tools="devbox_run devbox_list devbox_add devbox_info devbox_search devbox_docs_search devbox_docs_list devbox_docs_read"
for tool in $tools; do
  if echo "$server_content" | grep -q "case \"$tool\":"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ Handler exists for $tool"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ Handler missing for $tool"
  fi
done

test_summary
