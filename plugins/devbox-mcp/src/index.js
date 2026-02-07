#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execFile } from "child_process";
import { promisify } from "util";
import { tmpdir } from "os";
import { join } from "path";
import { existsSync, mkdirSync } from "fs";

const execFileAsync = promisify(execFile);

const server = new Server(
  {
    name: "devbox-mcp-server",
    version: "0.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Helper to run devbox commands
async function runDevbox(args, options = {}) {
  const { cwd = process.cwd(), timeout = 120000 } = options;
  try {
    const { stdout, stderr } = await execFileAsync("devbox", args, {
      cwd,
      timeout,
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer
    });
    return { success: true, stdout, stderr };
  } catch (error) {
    return {
      success: false,
      stdout: error.stdout || "",
      stderr: error.stderr || error.message,
      exitCode: error.code,
    };
  }
}

// Helper to ensure docs repo is available
async function ensureDocsRepo() {
  const docsDir = join(tmpdir(), "devbox-docs");
  const docsRepo = "https://github.com/jetify-com/docs.git";

  if (!existsSync(docsDir)) {
    mkdirSync(docsDir, { recursive: true });
    await execFileAsync("git", ["clone", "--depth", "1", docsRepo, docsDir], {
      timeout: 60000,
    });
  } else {
    // Update existing repo
    try {
      await execFileAsync("git", ["pull", "--depth", "1"], {
        cwd: docsDir,
        timeout: 30000,
      });
    } catch (pullError) {
      // If pull fails, try to re-clone
      await execFileAsync("rm", ["-rf", docsDir]);
      mkdirSync(docsDir, { recursive: true });
      await execFileAsync("git", ["clone", "--depth", "1", docsRepo, docsDir], {
        timeout: 60000,
      });
    }
  }

  return docsDir;
}

// Helper to search devbox docs
async function searchDocs(query, options = {}) {
  const { maxResults = 10 } = options;

  try {
    const docsDir = await ensureDocsRepo();

    // Search through docs using grep
    const { stdout } = await execFileAsync(
      "grep",
      [
        "-r",
        "-i",
        "-n",
        "-H",
        "--include=*.md",
        "--include=*.mdx",
        query,
        docsDir,
      ],
      {
        timeout: 30000,
        maxBuffer: 10 * 1024 * 1024,
      }
    );

    // Parse results and format
    const lines = stdout.split("\n").filter((line) => line.trim());
    const results = lines.slice(0, maxResults).map((line) => {
      const [filePath, ...rest] = line.split(":");
      const lineNum = rest[0];
      const content = rest.slice(1).join(":").trim();
      const relativePath = filePath.replace(docsDir + "/", "");
      return { file: relativePath, line: lineNum, content };
    });

    return { success: true, results, total: lines.length };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      stderr: error.stderr || "",
    };
  }
}

// Helper to list documentation files
async function listDocs() {
  try {
    const docsDir = await ensureDocsRepo();

    // Find all markdown files
    const { stdout } = await execFileAsync(
      "find",
      [docsDir, "-type", "f", "-name", "*.md", "-o", "-type", "f", "-name", "*.mdx"],
      {
        timeout: 10000,
        maxBuffer: 10 * 1024 * 1024,
      }
    );

    const files = stdout
      .split("\n")
      .filter((line) => line.trim())
      .map((file) => file.replace(docsDir + "/", ""))
      .sort();

    return { success: true, files };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      stderr: error.stderr || "",
    };
  }
}

// Helper to read a specific doc file
async function readDoc(filePath) {
  try {
    const docsDir = await ensureDocsRepo();
    const fullPath = join(docsDir, filePath);

    // Security check: ensure the path is within docsDir
    if (!fullPath.startsWith(docsDir)) {
      return {
        success: false,
        error: "Invalid file path: must be within docs directory",
      };
    }

    if (!existsSync(fullPath)) {
      return {
        success: false,
        error: `File not found: ${filePath}`,
      };
    }

    const { stdout } = await execFileAsync("cat", [fullPath], {
      timeout: 10000,
      maxBuffer: 10 * 1024 * 1024,
    });

    return { success: true, content: stdout, filePath };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      stderr: error.stderr || "",
    };
  }
}

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "devbox_run",
        description:
          "Execute a devbox command or script. Can run scripts from devbox.json or any binary in PATH. Use this instead of manual bash commands for devbox operations.",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description:
                "Command or script to run (e.g., 'test', 'android.sh devices list', 'pytest')",
            },
            args: {
              type: "array",
              items: { type: "string" },
              description: "Additional arguments to pass to the command",
            },
            pure: {
              type: "boolean",
              description: "Run in isolated environment (--pure flag)",
              default: false,
            },
            env: {
              type: "object",
              description: "Environment variables to set",
              additionalProperties: { type: "string" },
            },
            cwd: {
              type: "string",
              description: "Working directory (defaults to current directory)",
            },
            timeout: {
              type: "number",
              description: "Timeout in milliseconds (default: 120000)",
              default: 120000,
            },
          },
          required: ["command"],
        },
      },
      {
        name: "devbox_list",
        description: "List installed packages in current devbox environment",
        inputSchema: {
          type: "object",
          properties: {
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
        },
      },
      {
        name: "devbox_add",
        description: "Add package(s) to devbox.json",
        inputSchema: {
          type: "object",
          properties: {
            packages: {
              type: "array",
              items: { type: "string" },
              description: "Packages to add (e.g., ['python@3.11', 'nodejs@20'])",
            },
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
          required: ["packages"],
        },
      },
      {
        name: "devbox_info",
        description: "Get information about a package",
        inputSchema: {
          type: "object",
          properties: {
            package: {
              type: "string",
              description: "Package name",
            },
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
          required: ["package"],
        },
      },
      {
        name: "devbox_search",
        description: "Search for packages in Nix registry",
        inputSchema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Search query",
            },
          },
          required: ["query"],
        },
      },
      {
        name: "devbox_docs_search",
        description: "Search the devbox documentation at github.com/jetify-com/docs for relevant information about devbox features, commands, and usage",
        inputSchema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Search query (e.g., 'init hook', 'services', 'plugins')",
            },
            maxResults: {
              type: "number",
              description: "Maximum number of results to return (default: 10)",
              default: 10,
            },
          },
          required: ["query"],
        },
      },
      {
        name: "devbox_docs_list",
        description: "List all available documentation files in the devbox documentation repository. Returns a list of file paths that can be read with devbox_docs_read.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "devbox_docs_read",
        description: "Read the full content of a specific documentation file. Use the file path from devbox_docs_search results or devbox_docs_list to read complete documentation.",
        inputSchema: {
          type: "object",
          properties: {
            filePath: {
              type: "string",
              description: "Path to the documentation file (e.g., 'app/docs/devbox.mdx', 'README.md')",
            },
          },
          required: ["filePath"],
        },
      },
      {
        name: "devbox_init",
        description: "Initialize a new devbox.json file in the specified directory. Creates a basic configuration that can be customized.",
        inputSchema: {
          type: "object",
          properties: {
            cwd: {
              type: "string",
              description: "Directory to initialize devbox in (defaults to current directory)",
            },
          },
        },
      },
      {
        name: "devbox_shell_env",
        description: "Get the environment variables that would be set in a devbox shell. Useful for understanding what PATH, variables, and tools are available.",
        inputSchema: {
          type: "object",
          properties: {
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "devbox_run": {
      const { command, args: cmdArgs = [], pure = false, env = {}, cwd, timeout } = args;

      const devboxArgs = ["run"];
      if (pure) devboxArgs.push("--pure");

      // Add environment variables
      for (const [key, value] of Object.entries(env)) {
        devboxArgs.push("-e", `${key}=${value}`);
      }

      devboxArgs.push(command);
      if (cmdArgs.length > 0) {
        devboxArgs.push(...cmdArgs);
      }

      const result = await runDevbox(devboxArgs, { cwd, timeout });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `✓ Command succeeded\n\nOutput:\n${result.stdout}${result.stderr ? `\nStderr:\n${result.stderr}` : ""}`
              : `✗ Command failed (exit ${result.exitCode})\n\nStdout:\n${result.stdout}\n\nStderr:\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_list": {
      const { cwd } = args;
      const result = await runDevbox(["list"], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? result.stdout
              : `Error: ${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_add": {
      const { packages, cwd } = args;
      const result = await runDevbox(["add", ...packages], { cwd, timeout: 180000 });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `✓ Added packages: ${packages.join(", ")}\n\n${result.stdout}`
              : `✗ Failed to add packages\n\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_info": {
      const { package: pkg, cwd } = args;
      const result = await runDevbox(["info", pkg], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? result.stdout
              : `Error: ${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_search": {
      const { query } = args;
      const result = await runDevbox(["search", query]);

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? result.stdout
              : `Error: ${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_docs_search": {
      const { query, maxResults = 10 } = args;
      const result = await searchDocs(query, { maxResults });

      if (!result.success) {
        return {
          content: [
            {
              type: "text",
              text: `✗ Failed to search docs\n\nError: ${result.error}\n${result.stderr ? `\nDetails: ${result.stderr}` : ""}`,
            },
          ],
          isError: true,
        };
      }

      if (result.results.length === 0) {
        return {
          content: [
            {
              type: "text",
              text: `No results found for "${query}" in devbox documentation.`,
            },
          ],
        };
      }

      // Format results
      const formattedResults = result.results.map(
        (r) => `${r.file}:${r.line}\n  ${r.content}`
      ).join("\n\n");

      return {
        content: [
          {
            type: "text",
            text: `Found ${result.total} match(es) for "${query}" (showing ${result.results.length}):\n\n${formattedResults}\n\nView docs: https://github.com/jetify-com/docs\n\nTip: Use devbox_docs_read with a file path to read the complete documentation.`,
          },
        ],
      };
    }

    case "devbox_docs_list": {
      const result = await listDocs();

      if (!result.success) {
        return {
          content: [
            {
              type: "text",
              text: `✗ Failed to list docs\n\nError: ${result.error}\n${result.stderr ? `\nDetails: ${result.stderr}` : ""}`,
            },
          ],
          isError: true,
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `Documentation files (${result.files.length}):\n\n${result.files.join("\n")}\n\nTip: Use devbox_docs_read to read any file.`,
          },
        ],
      };
    }

    case "devbox_docs_read": {
      const { filePath } = args;
      const result = await readDoc(filePath);

      if (!result.success) {
        return {
          content: [
            {
              type: "text",
              text: `✗ Failed to read doc\n\nError: ${result.error}\n${result.stderr ? `\nDetails: ${result.stderr}` : ""}`,
            },
          ],
          isError: true,
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `# ${result.filePath}\n\n${result.content}`,
          },
        ],
      };
    }

    case "devbox_init": {
      const { cwd } = args;
      const result = await runDevbox(["init"], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `✓ Initialized devbox.json\n\n${result.stdout}`
              : `✗ Failed to initialize devbox.json\n\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_shell_env": {
      const { cwd } = args;
      // Use 'devbox run' with 'env' command to get the shell environment
      const result = await runDevbox(["run", "env"], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `Environment variables in devbox shell:\n\n${result.stdout}`
              : `✗ Failed to get shell environment\n\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Devbox MCP server running on stdio");
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
