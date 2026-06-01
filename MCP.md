# MCP Server

## Build

```bash
cd MCPServer
swift build -c release
```

The executable will be at `MCPServer/.build/release/clrpkr-mcp`.

## Configuration

### GitHub Copilot (VS Code)

**Location:** `.vscode/mcp.json` in workspace or `~/Library/Application Support/Code/User/globalStorage/github.copilot-chat/mcp.json` for global

```json
{
  "servers": {
    "clrpkr": {
      "type": "stdio",
      "command": "/Users/username/bin/clrpkr-mcp"
    }
  }
}
```

Or if installed via Homebrew:

```json
{
  "servers": {
    "clrpkr": {
      "type": "stdio",
      "command": "/opt/homebrew/bin/clrpkr-mcp"
    }
  }
}
```

### Claude Desktop

**Location:** `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "clrpkr": {
      "command": "/Users/username/bin/clrpkr-mcp"
    }
  }
}
```

### Cursor IDE

**Location:** `~/.cursor/mcp.json`

```json
{
  "mcpServers": {
    "clrpkr": {
      "command": "/Users/username/bin/clrpkr-mcp",
      "args": []
    }
  }
}
```

### Windsurf IDE

**Location:** `~/.windsurf/mcp_config.json`

```json
{
  "mcpServers": {
    "clrpkr": {
      "command": "/Users/username/bin/clrpkr-mcp"
    }
  }
}
```

### Generic MCP Client

Any MCP client that supports stdio transport:

```json
{
  "command": "/path/to/clrpkr-mcp",
  "type": "stdio"
}
```
