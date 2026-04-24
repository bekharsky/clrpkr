# ClrPkr

ClrPkr is a native macOS color picker with:

- a unified titlebar toolbar for `On Top`, `Import`, and `Pick`
- a lens-style screen picker overlay
- selectable output formats (`HEX`, `RGB`, `HSL`, `SwiftUI`)
- imported image palettes with export actions
- a persistent pick history with quick copy/export

## Architecture

The app is a small AppKit + SwiftUI hybrid:

- [Runner/App/AppDelegate.swift](/Users/bekharsky/GIT/clrpkr/Runner/App/AppDelegate.swift) coordinates the app lifecycle, status bar, import flow, picker flow, and About window
- [Runner/UI/MainWindow.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/MainWindow.swift) owns the `NSWindow` and native toolbar
- [Runner/UI/ClrPkrStore.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/ClrPkrStore.swift) owns window state, imported palettes, history, and recent-picks publishing
- [Runner/UI/MainWindowRootView.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/MainWindowRootView.swift) contains the main SwiftUI layout and sections
- [Runner/UI/MainWindowComponents.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/MainWindowComponents.swift) contains reusable controls and small view components
- [Runner/UI/ColorModels.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/ColorModels.swift) contains formatting, export, and subtitle helpers
- [Runner/UI/ImagePaletteExtractor.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/ImagePaletteExtractor.swift) extracts dominant colors from imported images
- [Runner/UI/ColorNaming.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/ColorNaming.swift) maps picks to nearest color names
- [Runner/Picker/ScreenColorPicker.swift](/Users/bekharsky/GIT/clrpkr/Runner/Picker/ScreenColorPicker.swift) contains the screen picker and lens placement logic

## Build

Build a debug app bundle:

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -configuration Debug -derivedDataPath build/native build
```

Built app:

```bash
build/native/Build/Products/Debug/clrpkr.app
```

## Test

Run the unit test suite:

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -destination 'platform=macOS' -derivedDataPath build/native test
```

Current tests cover:

- color formatting and export-related helpers
- lens placement logic
- image palette extraction
- `ClrPkrStore` behavior for history, imported palettes, and recent picks

## Notes

- On the first real screen pick, macOS may ask for Screen Recording permission.
- Import supports individual image files and folders.
- Imported palettes also append their colors into history so they can be copied/exported immediately.
