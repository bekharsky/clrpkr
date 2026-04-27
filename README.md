# ClrPkr

ClrPkr is a native macOS color picker with:

- a lens-style screen picker overlay
- selectable output formats (`HEX`, `RGB`, `HSL`, `SwiftUI`)
- imported image palettes with export actions
- a persistent pick history with quick copy/export

## Screenshots

<img width="532" height="612" alt="Screenshot 2026-04-27 at 9 54 38" src="https://github.com/user-attachments/assets/7723da17-e68c-4c61-b007-dde71c0ffb29" />
<img width="532" height="612" alt="Screenshot 2026-04-27 at 9 54 28" src="https://github.com/user-attachments/assets/5e48a29d-3f1a-4151-a9e3-1d3575e84786" />
<img width="532" height="612" alt="Screenshot 2026-04-27 at 9 54 07" src="https://github.com/user-attachments/assets/84d55462-6ff0-49db-916a-61a263a0d2e8" />

## Architecture

The app is a small AppKit + SwiftUI hybrid:

- [Runner/App/AppDelegate.swift](/Users/bekharsky/GIT/clrpkr/Runner/App/AppDelegate.swift) coordinates the app lifecycle, import flow, picker flow, About window, and main-window wiring
- [Runner/App/StatusBarController.swift](/Users/bekharsky/GIT/clrpkr/Runner/App/StatusBarController.swift) owns the menu bar item and recent-picks menu
- [Runner/UI/MainWindow.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/MainWindow.swift) owns the `NSWindow`, titlebar, and native toolbar
- [Runner/UI/ClrPkrStore.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/ClrPkrStore.swift) owns window state, imported palettes, history, and recent-picks publishing
- [Runner/UI/MainWindowRootView.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/MainWindowRootView.swift) composes the main SwiftUI sections and handles drop/copy coordination
- [Runner/UI/ImportedPaletteSection.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/ImportedPaletteSection.swift) contains imported-palette layout, preview image, and swatch burst animation
- [Runner/UI/HistorySection.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/HistorySection.swift) contains the history list, footer actions, and drop overlay
- [Runner/UI/InteractiveControls.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/InteractiveControls.swift) contains interactive reusable controls such as history rows, palette swatches, and the format pill
- [Runner/UI/SharedControls.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/SharedControls.swift) contains shared AppKit/SwiftUI button wrappers and small helpers
- [Runner/UI/ColorModels.swift](/Users/bekharsky/GIT/clrpkr/Runner/UI/ColorModels.swift) contains formatting, export, and palette/history model helpers
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

Test files:

- [RunnerTests/RunnerTests.swift](/Users/bekharsky/GIT/clrpkr/RunnerTests/RunnerTests.swift)
- [RunnerTests/ClrPkrStoreTests.swift](/Users/bekharsky/GIT/clrpkr/RunnerTests/ClrPkrStoreTests.swift)

## Notes

- On the first real screen pick, macOS may ask for Screen Recording permission.
- Import supports individual image files and folders.
- Imported palettes also append their colors into history so they can be copied/exported immediately.
