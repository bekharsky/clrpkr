import AppKit
import ApplicationServices

/// Manages hiding and showing windows of the frontmost application
/// using macOS Accessibility APIs.
final class WindowManager {
  private var hiddenApp: NSRunningApplication?
  private var wasHidden = false
  
  /// Hides the main window of the currently active (frontmost) application.
  /// Returns true if successful.
  @discardableResult
  func hideFrontmostWindow() -> Bool {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
      return false
    }
    
    // Check if we have accessibility permissions
    guard AXIsProcessTrusted() else {
      NSLog("WindowManager: Accessibility permission not granted")
      return false
    }
    
    let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
    var windowRef: AnyObject?
    
    // Get the focused window
    let result = AXUIElementCopyAttributeValue(
      appElement,
      kAXFocusedWindowAttribute as CFString,
      &windowRef
    )
    
    guard result == .success, let window = windowRef else {
      NSLog("WindowManager: Could not get focused window")
      return false
    }
    
    // Check if the window is already hidden
    var isHidden: AnyObject?
    AXUIElementCopyAttributeValue(
      window as! AXUIElement,
      kAXHiddenAttribute as CFString,
      &isHidden
    )
    
    wasHidden = (isHidden as? Bool) ?? false
    
    // Hide the window
    let trueValue: CFTypeRef = kCFBooleanTrue
    let hideResult = AXUIElementSetAttributeValue(
      window as! AXUIElement,
      kAXHiddenAttribute as CFString,
      trueValue
    )
    
    if hideResult == .success {
      hiddenApp = frontApp
      NSLog("WindowManager: Successfully hid window for \(frontApp.localizedName ?? "unknown")")
      return true
    } else {
      NSLog("WindowManager: Failed to hide window: \(hideResult.rawValue)")
      return false
    }
  }
  
  /// Restores the previously hidden window.
  func showHiddenWindow() {
    guard let app = hiddenApp else {
      return
    }
    
    // Only restore if we actually hid it
    guard !wasHidden else {
      hiddenApp = nil
      return
    }
    
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var windowRef: AnyObject?
    
    let result = AXUIElementCopyAttributeValue(
      appElement,
      kAXFocusedWindowAttribute as CFString,
      &windowRef
    )
    
    if result == .success, let window = windowRef {
      let falseValue: CFTypeRef = kCFBooleanFalse
      AXUIElementSetAttributeValue(
        window as! AXUIElement,
        kAXHiddenAttribute as CFString,
        falseValue
      )
      NSLog("WindowManager: Restored window for \(app.localizedName ?? "unknown")")
    }
    
    // Activate the app to bring it back to front
    app.activate(options: [])
    
    hiddenApp = nil
    wasHidden = false
  }
  
  /// Checks if accessibility permissions are granted.
  static func hasAccessibilityPermissions() -> Bool {
    return AXIsProcessTrusted()
  }
  
  /// Requests accessibility permissions from the user.
  static func requestAccessibilityPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary)
  }
}
