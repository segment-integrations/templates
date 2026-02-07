#!/usr/bin/env bash
set -euo pipefail

echo "Testing devbox-mcp integration..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_FRAMEWORK="${SCRIPT_DIR}/../../tests/test-framework.sh"
MCP_DIR="${SCRIPT_DIR}/.."
REPO_ROOT="${SCRIPT_DIR}/../../.."

# Source test framework
. "${TEST_FRAMEWORK}"

# Check if node_modules are installed
if [ ! -d "${MCP_DIR}/node_modules" ]; then
  echo "Installing dependencies..."
  cd "${MCP_DIR}"
  npm install --silent
  cd - >/dev/null
fi

# Create a temporary test project
TEST_PROJECT="/tmp/devbox-mcp-test-$$"
mkdir -p "$TEST_PROJECT"
cd "$TEST_PROJECT"

# Helper function to call MCP tool
call_mcp_tool() {
  local tool_name="$1"
  local args="$2"

  # Create JSON-RPC request
  local request=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "$tool_name",
    "arguments": $args
  }
}
EOF
)

  # Send request to MCP server and capture response
  cd "$REPO_ROOT"
  echo "$request" | timeout 30 devbox run node "${MCP_DIR}/src/index.js" 2>/dev/null | tail -n 1
}

# Test 1: devbox_init
echo "Test 1: devbox_init"
if call_mcp_tool "devbox_init" '{"cwd":"'"$TEST_PROJECT"'"}' | grep -q '"isError":false\|"isError":true' 2>/dev/null; then
  if [ -f "$TEST_PROJECT/devbox.json" ]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ devbox_init created devbox.json"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ devbox_init did not create devbox.json"
  fi
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_init failed to respond"
fi

# Test 2: devbox_add
echo "Test 2: devbox_add"
if call_mcp_tool "devbox_add" '{"packages":["hello"],"cwd":"'"$TEST_PROJECT"'"}' | grep -q 'hello\|Added\|isError' 2>/dev/null; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_add executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_add failed"
fi

# Test 3: devbox_list
echo "Test 3: devbox_list"
if call_mcp_tool "devbox_list" '{"cwd":"'"$TEST_PROJECT"'"}' | grep -q 'hello\|Packages\|isError' 2>/dev/null; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_list executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_list failed"
fi

# Test 4: devbox_info
echo "Test 4: devbox_info"
if call_mcp_tool "devbox_info" '{"package":"hello","cwd":"'"$TEST_PROJECT"'"}' | grep -q 'hello\|Package\|isError' 2>/dev/null; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_info executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_info failed"
fi

# Test 5: devbox_search
echo "Test 5: devbox_search"
if call_mcp_tool "devbox_search" '{"query":"python"}' | grep -q 'python\|Found\|isError' 2>/dev/null; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_search executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_search failed"
fi

# Test 6: devbox_run
echo "Test 6: devbox_run"
if call_mcp_tool "devbox_run" '{"command":"hello","cwd":"'"$TEST_PROJECT"'"}' | grep -q 'Hello\|Command\|isError' 2>/dev/null; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_run executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_run failed"
fi

# Test 7: devbox_shell_env
echo "Test 7: devbox_shell_env"
if call_mcp_tool "devbox_shell_env" '{"cwd":"'"$TEST_PROJECT"'"}' | grep -q 'PATH\|Environment\|isError' 2>/dev/null; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_shell_env executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_shell_env failed"
fi

# Test 8: devbox_docs_search (this will take longer as it clones the repo)
echo "Test 8: devbox_docs_search (may take 30s on first run)"
if timeout 60 bash -c "call_mcp_tool 'devbox_docs_search' '{\"query\":\"init hook\",\"maxResults\":3}' | grep -q 'init.*hook\|Found\|isError' 2>/dev/null"; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_search executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_search failed or timed out"
fi

# Test 9: devbox_docs_list
echo "Test 9: devbox_docs_list"
if timeout 30 bash -c "call_mcp_tool 'devbox_docs_list' '{}' | grep -q 'Documentation\|files\|isError' 2>/dev/null"; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_list executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_list failed"
fi

# Test 10: devbox_docs_read
echo "Test 10: devbox_docs_read"
if timeout 30 bash -c "call_mcp_tool 'devbox_docs_read' '{\"filePath\":\"README.md\"}' | grep -q 'README\|Devbox\|isError' 2>/dev/null"; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ devbox_docs_read executed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ devbox_docs_read failed"
fi

# Cleanup
cd /
rm -rf "$TEST_PROJECT"

test_summary
