# Devbox MCP Server

Model Context Protocol server for [Jetify's devbox](https://www.jetify.com/devbox) development environment tool.

## Features

- Execute devbox commands and scripts in proper environment
- List, add, search, and get info about packages
- Support for isolated environments (`--pure`)
- Environment variable management
- Timeout configuration
- Working directory support

## Installation

### For Claude Code

```bash
# Install via npx (recommended)
claude mcp add devbox -- npx -y devbox-mcp-server

# Or install globally first
npm install -g devbox-mcp-server
claude mcp add devbox -- devbox-mcp-server
```

### For Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "devbox": {
      "command": "npx",
      "args": ["-y", "devbox-mcp-server"]
    }
  }
}
```

## Development

This plugin includes its own devbox environment for development:

```bash
cd plugins/devbox-mcp
devbox shell
npm install

# Test the server directly
node src/index.js

# Or configure Claude Code to use local development version
claude mcp add devbox -- node "$(pwd)/src/index.js"
```

Note: `npm link` won't work in devbox environments as the Nix store is read-only. Use the direct path approach instead.

## Available Tools

### `devbox_run`
Execute devbox commands or scripts.

```typescript
devbox_run({
  command: "test:fast",              // Script or command
  args: ["--verbose"],               // Optional arguments
  pure: true,                        // Run in isolated env
  env: { DEBUG: "1" },              // Environment variables
  cwd: "/path/to/project",          // Working directory
  timeout: 300000                    // Timeout in ms
})
```

### `devbox_list`
List installed packages in current devbox environment.

### `devbox_add`
Add packages to devbox.json.

```typescript
devbox_add({
  packages: ["python@3.11", "nodejs@20"],
  cwd: "/path/to/project"
})
```

### `devbox_info`
Get information about a package.

### `devbox_search`
Search for packages in Nix registry.

## Use Cases

- Running tests in proper devbox environment from Claude
- Managing packages without manual devbox commands
- Executing plugin scripts with correct dependencies
- Environment-aware command execution

## Requirements

- Node.js 18+
- devbox CLI installed and in PATH

## License

MIT
