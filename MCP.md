# MCP Server

## Available Tools

Both tools open native macOS UI and return results:

- **`pick_color`** - Opens magnified screen picker overlay, returns:
  - Hex color code
  - RGB values
  - HSL values
  - Visual color swatch (base64 PNG)
  - Nearest color name

- **`extract_palette`** - Opens file picker for image selection, returns:
  - Up to 8 dominant colors from the image
  - Each color with hex, name, and visual swatch
  - Formatted as markdown table

## Build

```bash
cd MCPServer
swift build -c release
```

The executable will be at `MCPServer/.build/release/pipetka-mcp`.

## Configuration

### GitHub Copilot (VS Code)

**Location:** `.vscode/mcp.json` in workspace or `~/Library/Application Support/Code/User/globalStorage/github.copilot-chat/mcp.json` for global

```json
{
  "servers": {
    "pipetka": {
      "type": "stdio",
      "command": "/Users/username/bin/pipetka-mcp"
    }
  }
}
```

Or if installed via Homebrew:

```json
{
  "servers": {
    "pipetka": {
      "type": "stdio",
      "command": "/opt/homebrew/bin/pipetka-mcp"
    }
  }
}
```

### Claude Desktop

**Location:** `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "pipetka": {
      "command": "/Users/username/bin/pipetka-mcp"
    }
  }
}
```

### Cursor IDE

**Location:** `~/.cursor/mcp.json`

```json
{
  "mcpServers": {
    "pipetka": {
      "command": "/Users/username/bin/pipetka-mcp",
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
    "pipetka": {
      "command": "/Users/username/bin/pipetka-mcp"
    }
  }
}
```

### Generic MCP Client

Any MCP client that supports stdio transport:

```json
{
  "command": "/path/to/pipetka-mcp",
  "type": "stdio"
}
```
