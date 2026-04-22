# ClrPkr

ClrPkr is a native macOS colour picker with a menu bar presence, a native lens-style picker overlay, selectable output formats, and a custom AppKit history window.

## Features

- Native macOS picker overlay that samples any on-screen pixel.
- Native AppKit utility window with format switching, hover states, and copy interactions.
- History list with preview snippets for earlier picks.
- Click any history row to copy the selected format to the clipboard.
- Menu bar app behavior via a system status item.

## Run

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -configuration Debug -derivedDataPath build/native build
```

The built app will be at:

```bash
build/native/Build/Products/Debug/clrpkr.app
```

On the first real pick, macOS will likely ask for Screen Recording permission so the app can sample pixels outside its own window.
