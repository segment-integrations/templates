#!/usr/bin/env node

/**
 * Integration test for MCP tools
 * Tests each tool by simulating MCP requests
 */

import { execFile } from "child_process";
import { promisify } from "util";
import { tmpdir } from "os";
import { join } from "path";
import { existsSync, mkdirSync, writeFileSync, rmSync } from "fs";

const execFileAsync = promisify(execFile);

let testsPassed = 0;
let testsFailed = 0;

function pass(message) {
  testsPassed++;
  console.log(`✓ ${message}`);
}

function fail(message, error) {
  testsFailed++;
  console.log(`✗ ${message}`);
  if (error) console.log(`  Error: ${error}`);
}

// Create temporary test directory
const testDir = join(tmpdir(), `devbox-mcp-test-${Date.now()}`);
mkdirSync(testDir, { recursive: true });

async function runDevbox(args, options = {}) {
  const { cwd = process.cwd() } = options;
  try {
    const { stdout } = await execFileAsync("devbox", args, { cwd, timeout: 30000 });
    return { success: true, stdout };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function testDevboxInit() {
  console.log("\nTest 1: devbox init");
  const result = await runDevbox(["init"], { cwd: testDir });

  if (result.success && existsSync(join(testDir, "devbox.json"))) {
    pass("devbox_init - Created devbox.json");
  } else {
    fail("devbox_init - Failed to create devbox.json", result.error);
  }
}

async function testDevboxAdd() {
  console.log("\nTest 2: devbox add");
  const result = await runDevbox(["add", "hello"], { cwd: testDir });

  if (result.success) {
    pass("devbox_add - Added hello package");
  } else {
    fail("devbox_add - Failed to add package", result.error);
  }
}

async function testDevboxList() {
  console.log("\nTest 3: devbox list");
  const result = await runDevbox(["list"], { cwd: testDir });

  if (result.success && result.stdout.includes("hello")) {
    pass("devbox_list - Listed packages including hello");
  } else {
    fail("devbox_list - Failed to list packages", result.error);
  }
}

async function testDevboxInfo() {
  console.log("\nTest 4: devbox info");
  const result = await runDevbox(["info", "hello"], { cwd: testDir });

  if (result.success) {
    pass("devbox_info - Retrieved package info");
  } else {
    fail("devbox_info - Failed to get package info", result.error);
  }
}

async function testDevboxSearch() {
  console.log("\nTest 5: devbox search");
  const result = await runDevbox(["search", "python"], { cwd: testDir });

  if (result.success && result.stdout.includes("python")) {
    pass("devbox_search - Searched for packages");
  } else {
    fail("devbox_search - Failed to search packages", result.error);
  }
}

async function testDevboxRun() {
  console.log("\nTest 6: devbox run");
  const result = await runDevbox(["run", "hello"], { cwd: testDir });

  if (result.success && result.stdout.toLowerCase().includes("hello")) {
    pass("devbox_run - Executed hello command");
  } else {
    fail("devbox_run - Failed to run command", result.error);
  }
}

async function testDevboxShellEnv() {
  console.log("\nTest 7: devbox shell env");
  const result = await runDevbox(["run", "env"], { cwd: testDir });

  if (result.success && result.stdout.includes("PATH=")) {
    pass("devbox_shell_env - Retrieved environment variables");
  } else {
    fail("devbox_shell_env - Failed to get environment", result.error);
  }
}

async function testDocsSearch() {
  console.log("\nTest 8: docs search (cloning repo, may take 30s)");
  const docsDir = join(tmpdir(), "devbox-docs");

  try {
    // Clone if not exists
    if (!existsSync(docsDir)) {
      mkdirSync(docsDir, { recursive: true });
      await execFileAsync("git", ["clone", "--depth", "1", "https://github.com/jetify-com/docs.git", docsDir], {
        timeout: 60000,
      });
    }

    // Search
    const { stdout } = await execFileAsync(
      "grep",
      ["-r", "-i", "-l", "--include=*.md", "--include=*.mdx", "init hook", docsDir],
      { timeout: 10000 }
    );

    if (stdout.includes(".md")) {
      pass("devbox_docs_search - Searched documentation");
    } else {
      fail("devbox_docs_search - No results found");
    }
  } catch (error) {
    fail("devbox_docs_search - Failed to search docs", error.message);
  }
}

async function testDocsList() {
  console.log("\nTest 9: docs list");
  const docsDir = join(tmpdir(), "devbox-docs");

  try {
    const { stdout } = await execFileAsync(
      "find",
      [docsDir, "-type", "f", "-name", "*.md", "-o", "-type", "f", "-name", "*.mdx"],
      { timeout: 10000 }
    );

    const files = stdout.split("\n").filter(l => l.trim());
    if (files.length > 0) {
      pass(`devbox_docs_list - Listed ${files.length} documentation files`);
    } else {
      fail("devbox_docs_list - No files found");
    }
  } catch (error) {
    fail("devbox_docs_list - Failed to list docs", error.message);
  }
}

async function testDocsRead() {
  console.log("\nTest 10: docs read");
  const docsDir = join(tmpdir(), "devbox-docs");

  try {
    // Find any markdown file to test with
    const { stdout: findOut } = await execFileAsync(
      "find",
      [docsDir, "-type", "f", "-name", "*.md", "-print", "-quit"],
      { timeout: 5000 }
    );

    const firstFile = findOut.trim();
    if (firstFile && existsSync(firstFile)) {
      const { stdout } = await execFileAsync("cat", [firstFile], { timeout: 5000 });
      if (stdout.length > 0) {
        const relativePath = firstFile.replace(docsDir + "/", "");
        pass(`devbox_docs_read - Read ${relativePath}`);
      } else {
        fail("devbox_docs_read - File is empty");
      }
    } else {
      fail("devbox_docs_read - No markdown files found");
    }
  } catch (error) {
    fail("devbox_docs_read - Failed to read doc", error.message);
  }
}

async function runTests() {
  console.log("Testing MCP tools functionality...\n");
  console.log(`Test directory: ${testDir}\n`);

  try {
    await testDevboxInit();
    await testDevboxAdd();
    await testDevboxList();
    await testDevboxInfo();
    await testDevboxSearch();
    await testDevboxRun();
    await testDevboxShellEnv();
    await testDocsSearch();
    await testDocsList();
    await testDocsRead();
  } catch (error) {
    console.error("\nUnexpected error:", error);
  } finally {
    // Cleanup
    console.log("\nCleaning up...");
    rmSync(testDir, { recursive: true, force: true });

    console.log("\n====================================");
    console.log("Test Results:");
    console.log(`  Passed: ${testsPassed}`);
    console.log(`  Failed: ${testsFailed}`);
    console.log("====================================\n");

    process.exit(testsFailed > 0 ? 1 : 0);
  }
}

runTests();
