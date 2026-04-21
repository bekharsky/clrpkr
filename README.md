# ClrPkr

ClrPkr is a macOS Flutter colour picker with a menu bar presence, a native lens-style picker overlay, selectable output formats, and clipboard copy powered by `super_clipboard`.

## Features

- Native macOS picker overlay that samples any on-screen pixel.
- Custom chrome window styled after the warm, tactile feel of Pick.
- History list with preview snippets for earlier picks.
- Click any history row to copy the selected format to the clipboard.
- Menu bar app behavior via a system status item.

## Run

```bash
flutter pub get
flutter run -d macos
```

On the first real pick, macOS will likely ask for Screen Recording permission so the app can sample pixels outside its own window.
