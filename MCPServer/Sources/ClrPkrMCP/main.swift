import AppKit
import CoreGraphics

// Set up a background-only NSApplication (no Dock icon).
// AppKit is required so the picker overlay panels can run.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Request screen recording permission once the run loop is live.
DispatchQueue.main.async {
  if !CGPreflightScreenCaptureAccess() {
    CGRequestScreenCaptureAccess()
  }
  
  // Request accessibility permission for window management
  if !WindowManager.hasAccessibilityPermissions() {
    WindowManager.requestAccessibilityPermissions()
  }

  let server = MCPServer()
  DispatchQueue.global(qos: .userInitiated).async {
    server.readLoop()
  }
}

app.run()
