#!/usr/bin/env bash
set -euo pipefail

echo "Testing devbox-mcp server..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_FRAMEWORK="${SCRIPT_DIR}/../../tests/test-framework.sh"
MCP_DIR="${SCRIPT_DIR}/.."

# Source test framework
. "${TEST_FRAMEWORK}"

# Test 1: Check server file exists
assert_file_exists "${MCP_DIR}/src/index.js" "Server file exists"

# Test 2: Check package.json exists and is valid
assert_file_exists "${MCP_DIR}/package.json" "package.json exists"
assert_file_contains "${MCP_DIR}/package.json" "\"devbox-mcp\"" "package.json has correct name"
assert_file_contains "${MCP_DIR}/package.json" "@modelcontextprotocol/sdk" "package.json has MCP SDK dependency"

# Test 3: Check plugin.json exists and is valid
assert_file_exists "${MCP_DIR}/plugin.json" "plugin.json exists"
assert_file_contains "${MCP_DIR}/plugin.json" "devbox-mcp" "plugin.json has correct name"
assert_file_contains "${MCP_DIR}/plugin.json" "process-compose" "plugin.json includes process-compose"

# Test 4: Check process-compose.yaml exists
assert_file_exists "${MCP_DIR}/config/process-compose.yaml" "process-compose.yaml exists"
assert_file_contains "${MCP_DIR}/config/process-compose.yaml" "mcp-server" "process-compose.yaml defines mcp-server process"

# Test 5: Validate Node.js syntax
echo "Validating Node.js syntax..."
# Change to repo root to use devbox run
cd "${SCRIPT_DIR}/../.." || exit 1
if devbox run node --check plugins/devbox-mcp/src/index.js >/dev/null 2>&1; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ Server JavaScript syntax is valid"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Server JavaScript syntax has errors"
fi
cd "${SCRIPT_DIR}" || exit 1

# Test 6: Check all required tools are defined
echo "Checking required tools are defined..."
required_tools="devbox_run devbox_list devbox_add devbox_info devbox_search devbox_docs_search devbox_docs_list devbox_docs_read"
for tool in $required_tools; do
  if grep -q "name: \"$tool\"" "${MCP_DIR}/src/index.js"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ Tool defined: $tool"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ Tool missing: $tool"
  fi
done

# Test 7: Check server has proper imports
assert_file_contains "${MCP_DIR}/src/index.js" "@modelcontextprotocol/sdk/server/index.js" "Server imports MCP SDK"
assert_file_contains "${MCP_DIR}/src/index.js" "StdioServerTransport" "Server imports StdioServerTransport"

# Test 8: Check server has proper error handling
assert_file_contains "${MCP_DIR}/src/index.js" "catch.*error" "Server has error handling"

test_summary
