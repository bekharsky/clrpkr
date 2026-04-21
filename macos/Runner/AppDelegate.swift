import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate, FlutterStreamHandler {
  private var statusItem: NSStatusItem?
  private var pickEventSink: FlutterEventSink?
  private var pickerBridge: ScreenColorPickerBridge?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var channelsConfigured = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    configureStatusItem()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    hideMainWindow()
    return false
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    pickEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    pickEventSink = nil
    return nil
  }

  @objc
  private func toggleMainWindow(_ sender: Any?) {
    guard let window = mainFlutterWindow else {
      return
    }

    if window.isVisible {
      hideMainWindow()
    } else {
      showMainWindow()
    }
  }

  @objc
  private func quitApp(_ sender: Any?) {
    NSApp.terminate(nil)
  }

  private func showMainWindow() {
    guard let window = mainFlutterWindow else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func hideMainWindow() {
    mainFlutterWindow?.orderOut(nil)
  }

  private func configureStatusItem() {
    let menu = NSMenu()
    menu.addItem(
      withTitle: "Show / Hide Window",
      action: #selector(toggleMainWindow(_:)),
      keyEquivalent: ""
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      withTitle: "Quit ClrPkr",
      action: #selector(quitApp(_:)),
      keyEquivalent: "q"
    )

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.menu = menu

    if let button = statusItem?.button {
      if #available(macOS 11.0, *) {
        button.image = NSImage(
          systemSymbolName: "eyedropper.halffull",
          accessibilityDescription: "ClrPkr"
        )
        button.imagePosition = .imageOnly
      } else {
        button.title = "ClrPkr"
      }
      button.toolTip = "ClrPkr"
    }
  }

  func configureFlutterBindings(
    flutterViewController: FlutterViewController,
    window: NSWindow
  ) {
    if channelsConfigured {
      return
    }

    window.delegate = self
    let messenger: FlutterBinaryMessenger = flutterViewController.engine.binaryMessenger

    let methodChannel = FlutterMethodChannel(
      name: "clrpkr/methods",
      binaryMessenger: messenger
    )
    let eventChannel = FlutterEventChannel(
      name: "clrpkr/picks",
      binaryMessenger: messenger
    )

    eventChannel.setStreamHandler(self)
    self.methodChannel = methodChannel
    self.eventChannel = eventChannel
    channelsConfigured = true

    pickerBridge = ScreenColorPickerBridge(
      hideWindow: { [weak self] in
        self?.hideMainWindow()
      },
      showWindow: { [weak self] in
        self?.showMainWindow()
      },
      onPick: { [weak self] payload in
        self?.pickEventSink?(payload)
      }
    )

    methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self else {
        result(
          FlutterError(
            code: "app_delegate_missing",
            message: "App delegate is unavailable.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "startPicker":
        self.pickerBridge?.start()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
