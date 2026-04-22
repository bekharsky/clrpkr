# ClrPkr

ClrPkr is a native macOS color picker with a menu bar presence, a lens-style picker overlay, selectable output formats, and a custom AppKit history window.

## Build

Build a debug app bundle with Xcode's command line tools:

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -configuration Debug -destination 'platform=macOS' -derivedDataPath build/debug build
```

The built app will be at:

```bash
build/debug/Build/Products/Debug/clrpkr.app
```

## Test

Run the XCTest target from the command line:

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -destination 'platform=macOS' -derivedDataPath build/test test
```

The test suite covers:

- Color string formatting for `HEX`, `RGB`, `HSL`, and SwiftUI output
- Lens overlay frame placement near normal and edge-of-screen positions

## Notes

On the first real pick, macOS will likely ask for Screen Recording permission so the app can sample pixels outside its own window.
