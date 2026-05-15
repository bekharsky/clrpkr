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

The MCP server allows AI assistants to interact with ClrPkr's color picking functionality.

### Installation for Users

1. **Build the MCP server** (see Build section above)

2. **Configure in VS Code** - Add to `.vscode/mcp.json`:

```json
{
  "servers": {
    "clrpkr": {
      "type": "stdio",
      "command": "/absolute/path/to/MCPServer/.build/release/clrpkr-mcp"
    }
  }
}
```

3. **Configure in Claude Desktop** - Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "clrpkr": {
      "command": "/absolute/path/to/MCPServer/.build/release/clrpkr-mcp"
    }
  }
}
```

4. **Restart the AI assistant** for the configuration to take effect

### Available Tools

- **`pick_color`** - Opens screen picker overlay, returns color data with visual swatch
- **`extract_palette`** - Opens file picker to extract dominant colors from images

### Requirements

- macOS (screen picker requires native APIs)
- Screen Recording permission (granted on first use)

### Distribution Options

**Option 1: Distribute Source**
- Users clone the repo and build the MCP server themselves
- Best for developers comfortable with Swift

**Option 2: Distribute Binary**
- Build release binary: `cd MCPServer && swift build -c release`
- Archive the executable: `tar -czf clrpkr-mcp.tar.gz -C .build/release clrpkr-mcp`
- Users extract and configure the path in their MCP settings
- Note: Binary must be code-signed for Gatekeeper on macOS

**Option 3: Homebrew Formula**
- Create a Homebrew tap for easy installation
- Users can install with: `brew install your-tap/clrpkr-mcp`
- Automatically handles building and path configuration

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
