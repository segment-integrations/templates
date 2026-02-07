#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execFile } from "child_process";
import { promisify } from "util";

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
