# ClrPkr

A native macOS color picker app with AI assistant integration.

## Features

### Desktop App

- **Screen Color Picker** - Magnified lens overlay to sample any pixel on screen with precise crosshair targeting
- **Multiple Output Formats** - Copy colors as HEX, RGB, HSL, or SwiftUI Color syntax
- **Color Names** - Automatically identifies nearest named color for every pick (1,500+ color database)
- **Pick History** - Persistent history with quick copy, export, and visual swatches
- **Image Palette Extraction** - Import images to extract dominant color palettes (up to 8 colors)
- **Batch Export** - Export palettes and history as CSS Variables, SCSS, Tailwind config, or JSON tokens
- **Menu Bar Integration** - Quick access to recent picks via menu bar item
- **Drag & Drop Support** - Drop images or folders to extract color palettes

### MCP Server (AI Assistant)

ClrPkr includes a Model Context Protocol (MCP) server that exposes color picking functionality to AI assistants like Claude and GitHub Copilot:

- **`pick_color`** - Opens the interactive screen picker and returns hex, rgb, hsl values with visual swatch and color name
- **`extract_palette`** - Opens file picker to extract dominant colors from images with swatches and names

The MCP server allows AI assistants to help you pick colors and extract palettes directly from conversations.

## Screenshots

<img width="532" height="612" alt="Screenshot 2026-04-27 at 9 54 07" src="https://github.com/user-attachments/assets/84d55462-6ff0-49db-916a-61a263a0d2e8" />
<img width="532" height="612" alt="Screenshot 2026-04-27 at 9 54 28" src="https://github.com/user-attachments/assets/5e48a29d-3f1a-4151-a9e3-1d3575e84786" />
<img width="532" height="612" alt="Screenshot 2026-04-27 at 9 54 38" src="https://github.com/user-attachments/assets/7723da17-e68c-4c61-b007-dde71c0ffb29" />

## Architecture

The project consists of three main components:

- **Runner** - The native macOS app (AppKit + SwiftUI) with the main UI, history management, and screen picker
- **MCPServer** - A Swift stdio-based MCP server that exposes color picking tools to AI assistants
- **ClrPkrCore** - Shared Swift package containing core logic used by both Runner and MCPServer:
  - Color naming database and lookup
  - Screen color picker implementation
  - Image palette extraction
  - Color utilities and models

## Build

### Desktop App

Build the macOS app to `build/native/Release/`:

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -configuration Release SYMROOT="$PWD/build/native" build
```

Built app location:

```bash
build/native/Release/clrpkr.app
```

### MCP Server

Build the MCP server executable:

```bash
cd MCPServer
swift build -c release
```

Built executable:

```bash
MCPServer/.build/release/clrpkr-mcp
```

## MCP Server Distribution

The MCP server is a command-line executable that AI assistants communicate with via stdio. Here's how to distribute it for different platforms.

### Building for Distribution

```bash
cd MCPServer
swift build -c release
```

The executable will be at: `MCPServer/.build/release/clrpkr-mcp` (1.4 MB)

### Distribution Methods

#### Method 1: Pre-built Binary (Recommended for End Users)

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

#### Method 2: Homebrew Formula (Best for macOS)

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

#### Method 3: Source Distribution (For Developers)

Users clone and build themselves:

```bash
git clone https://github.com/yourusername/clrpkr.git
cd clrpkr/MCPServer
swift build -c release
```

### Configuration for Different AI Agents

#### GitHub Copilot (VS Code)

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

#### Claude Desktop

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

#### Cursor IDE

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

#### Windsurf IDE

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

#### Generic MCP Client

Any MCP client that supports stdio transport:

```json
{
  "command": "/path/to/clrpkr-mcp",
  "type": "stdio"
}
```

### Available Tools

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

### Requirements

- macOS 12.0 or later
- Screen Recording permission (system will prompt on first use)
- No additional dependencies required

### Testing the Installation

After configuration, restart the AI assistant and try:

- "pick a color from my screen"
- "extract colors from an image"

The MCP server will launch automatically when needed.

## Test

Run the unit test suite:

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -destination 'platform=macOS' test
```

Tests cover color formatting, export helpers, lens placement logic, image palette extraction, and `ClrPkrStore` behavior.

## Notes

- **Screen Recording Permission**: On first use, macOS will prompt for Screen Recording permission to enable the color picker
- **Image Import**: Supports individual image files, multiple selections, and entire folders
- **History Integration**: Colors from imported palettes are automatically added to history for immediate access
- **Color Names**: Powered by a database of 1,500+ named colors for automatic color identification
