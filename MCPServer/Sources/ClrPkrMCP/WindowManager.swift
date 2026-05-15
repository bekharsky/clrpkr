import AppKit
import ApplicationServices

/// Manages minimizing and restoring windows of the frontmost application
/// using macOS Accessibility APIs.
final class WindowManager {
  private var targetApp: NSRunningApplication?
  private var targetWindow: AXUIElement?
  private var wasHidden = false
  
  /// Captures the currently frontmost application for later window manipulation.
  /// Call this BEFORE starting the picker to remember which app to hide.
  func captureFrontmostApp() {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
      NSLog("WindowManager: No frontmost app to capture or frontmost is self")
      return
    }
    
    targetApp = frontApp
    NSLog("WindowManager: Captured app: \(frontApp.localizedName ?? "unknown") (PID: \(frontApp.processIdentifier))")
  }
  
  /// Minimizes the main window of the previously captured application.
  /// Returns true if successful.
  @discardableResult
  func hideWindow() -> Bool {
    guard let app = targetApp else {
      NSLog("WindowManager: No target app captured")
      return false
    }
    
    NSLog("WindowManager: Attempting to hide window for \(app.localizedName ?? "unknown") (PID: \(app.processIdentifier))")
    
    // Check if we have accessibility permissions
    let hasPerm = AXIsProcessTrusted()
    NSLog("WindowManager: Accessibility permission granted: \(hasPerm)")
    guard hasPerm else {
      NSLog("WindowManager: Accessibility permission not granted - cannot hide window")
      return false
    }
    
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var windowRef: AnyObject?
    
    // Get the focused window
    let result = AXUIElementCopyAttributeValue(
      appElement,
      kAXFocusedWindowAttribute as CFString,
      &windowRef
    )
    
    guard result == .success, let window = windowRef else {
      NSLog("WindowManager: Could not get focused window (error: \(result.rawValue))")
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
    NSLog("WindowManager: Window was already hidden: \(wasHidden)")
    
    // Try to minimize the window instead of hiding it
    // (Many apps like VS Code don't support the hidden attribute)
    var isMinimized: AnyObject?
    AXUIElementCopyAttributeValue(
      window as! AXUIElement,
      kAXMinimizedAttribute as CFString,
      &isMinimized
    )
    
    let wasMinimized = (isMinimized as? Bool) ?? false
    NSLog("WindowManager: Window was already minimized: \(wasMinimized)")
    
    if wasMinimized {
      NSLog("WindowManager: Window already minimized, nothing to do")
      return true
    }
    
    let trueValue: CFTypeRef = kCFBooleanTrue
    let minimizeResult = AXUIElementSetAttributeValue(
      window as! AXUIElement,
      kAXMinimizedAttribute as CFString,
      trueValue
    )
    
    if minimizeResult == .success {
      NSLog("WindowManager: Successfully minimized window")
      targetWindow = (window as! AXUIElement)
      return true
    } else {
      NSLog("WindowManager: Failed to minimize window (error: \(minimizeResult.rawValue))")
      return false
    }
  }
  
  /// Hides the main window of the currently active (frontmost) application.
  /// Returns true if successful.
  /// @deprecated Use captureFrontmostApp() followed by hideWindow() instead.
  @discardableResult
  func hideFrontmostWindow() -> Bool {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
      NSLog("WindowManager: No frontmost app or frontmost is self")
      return false
    }
    
    NSLog("WindowManager: Attempting to hide window for \(frontApp.localizedName ?? "unknown") (PID: \(frontApp.processIdentifier))")
    
    // Check if we have accessibility permissions
    let hasPerm = AXIsProcessTrusted()
    NSLog("WindowManager: Accessibility permission granted: \(hasPerm)")
    guard hasPerm else {
      NSLog("WindowManager: Accessibility permission not granted - cannot hide window")
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
      NSLog("WindowManager: Successfully hid window for \(frontApp.localizedName ?? "unknown")")
      targetApp = frontApp
      return true
    } else {
      NSLog("WindowManager: Failed to hide window: \(hideResult.rawValue)")
      return false
    }
  }
  
  /// Restores the previously hidden window.
  func showHiddenWindow() {
    guard let app = targetApp else {
      NSLog("WindowManager: No target app to restore")
      return
    }
    
    guard let window = targetWindow else {
      NSLog("WindowManager: No target window to restore")
      return
    }
    
    NSLog("WindowManager: Attempting to restore window for \(app.localizedName ?? "unknown")")
    
    // Only restore if we actually minimized it
    guard !wasHidden else {
      NSLog("WindowManager: Window was already minimized before we started, not restoring")
      targetApp = nil
      targetWindow = nil
      return
    }
    
    let falseValue: CFTypeRef = kCFBooleanFalse
    let showResult = AXUIElementSetAttributeValue(
      window,
      kAXMinimizedAttribute as CFString,
      falseValue
    )
    if showResult == .success {
      NSLog("WindowManager: Successfully unminimized window")
    } else {
      NSLog("WindowManager: Failed to unminimize window (error: \(showResult.rawValue))")
    }
    
    // Try to raise the window to front
    let raiseResult = AXUIElementPerformAction(
      window,
      kAXRaiseAction as CFString
    )
    if raiseResult == .success {
      NSLog("WindowManager: Successfully raised window to front")
    } else {
      NSLog("WindowManager: Failed to raise window (error: \(raiseResult.rawValue))")
    }
    
    // Activate the app with force to bring it to front
    app.activate(options: [.activateIgnoringOtherApps])
    NSLog("WindowManager: Reactivated app with force")
    
    targetApp = nil
    targetWindow = nil
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
