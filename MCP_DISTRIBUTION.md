# MCP Server Distribution Guide

The MCP server is a command-line executable that AI assistants communicate with via stdio. Here's how to distribute it for different platforms.

## Building for Distribution

```bash
cd MCPServer
swift build -c release
```

The executable will be at: `MCPServer/.build/release/clrpkr-mcp` (1.4 MB)

## Distribution Methods

### Method 1: Pre-built Binary (Recommended for End Users)

**Create distributable archive:**

```bash
cd MCPServer
swift build -c release
tar -czf clrpkr-mcp-macos.tar.gz -C .build/release clrpkr-mcp
```

**User installation:**

```bash
# Download and extract
tar -xzf clrpkr-mcp-macos.tar.gz
mkdir -p ~/bin
mv clrpkr-mcp ~/bin/
chmod +x ~/bin/clrpkr-mcp
```

**Important:** The binary must be code-signed or users will need to:

```bash
xattr -d com.apple.quarantine ~/bin/clrpkr-mcp
```

### Method 2: Homebrew Formula (Best for macOS)

Create a Homebrew tap repository:

**Formula template:**

```ruby
class ClrpkrMcp < Formula
  desc "MCP server for ClrPkr color picker"
  homepage "https://github.com/yourusername/clrpkr"
  url "https://github.com/yourusername/clrpkr/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "..."

  depends_on xcode: ["14.0", :build]

  def install
    cd "MCPServer" do
      system "swift", "build", "-c", "release", "--disable-sandbox"
      bin.install ".build/release/clrpkr-mcp"
    end
  end

  test do
    # Test that the binary exists and is executable
    assert_predicate bin/"clrpkr-mcp", :exist?
    assert_predicate bin/"clrpkr-mcp", :executable?
  end
end
```

**Users install with:**

```bash
brew tap yourusername/clrpkr
brew install clrpkr-mcp
```

### Method 3: Source Distribution (For Developers)

Users clone and build themselves:

```bash
git clone https://github.com/yourusername/clrpkr.git
cd clrpkr/MCPServer
swift build -c release
```

## Configuration for Different AI Agents

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

## Requirements

- macOS 12.0 or later
- **Screen Recording permission** (system will prompt on first use) - Required for color picking
- **Accessibility permission** (system will prompt on first use) - Required to hide IDE window during color picking
- No additional dependencies required

## Testing the Installation

After configuration, restart the AI assistant and try:

- "pick a color from my screen"
- "extract colors from an image"

The MCP server will launch automatically when needed.
