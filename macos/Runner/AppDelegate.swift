import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate, FlutterStreamHandler {
  private var statusItem: NSStatusItem?
  private var statusMenu = NSMenu()
  private var recentPickTexts: [String] = []
  private var pickEventSink: FlutterEventSink?
  private var pickerBridge: ScreenColorPickerBridge?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var channelsConfigured = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    DispatchQueue.main.async { [weak self] in
      self?.configureStatusItem()
    }
  }

  override func applicationDidBecomeActive(_ notification: Notification) {
    super.applicationDidBecomeActive(notification)

    if statusItem == nil || statusItem?.button == nil {
      DispatchQueue.main.async { [weak self] in
        self?.configureStatusItem()
      }
    }
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

  @objc
  private func showAbout(_ sender: Any?) {
    NSApp.orderFrontStandardAboutPanel(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc
  func startPickerFromToolbar(_ sender: Any?) {
    pickerBridge?.start()
  }

  @objc
  private func copyRecentPick(_ sender: NSMenuItem) {
    guard let text = sender.representedObject as? String else {
      return
    }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  @objc
  private func openStatusMenu(_ sender: Any?) {
    guard let button = statusItem?.button else {
      return
    }
    statusItem?.popUpMenu(statusMenu)
    button.highlight(false)
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
    if let existingItem = statusItem {
      NSStatusBar.system.removeStatusItem(existingItem)
    }

    statusItem = NSStatusBar.system.statusItem(withLength: 36)
    statusItem?.isVisible = true
    rebuildStatusMenu()

    if let button = statusItem?.button {
      button.title = "PK"
      button.image = nil
      button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
      button.imagePosition = .noImage
      button.isHidden = false
      button.appearsDisabled = false
      button.target = self
      button.action = #selector(openStatusMenu(_:))
      button.toolTip = "ClrPkr"
      button.sizeToFit()
      NSLog(
        "ClrPkr status button frame=%@ hidden=%@ window=%@",
        NSStringFromRect(button.frame),
        button.isHidden.description,
        String(describing: button.window)
      )
    } else {
      NSLog("ClrPkr status item has no button")
    }

    NSLog("ClrPkr status item configured: %@", statusItem?.description ?? "nil")
  }

  private func rebuildStatusMenu() {
    statusMenu.removeAllItems()
    statusMenu.addItem(
      withTitle: "Pick",
      action: #selector(startPickerFromToolbar(_:)),
      keyEquivalent: ""
    )
    statusMenu.addItem(NSMenuItem.separator())

    if recentPickTexts.isEmpty {
      let empty = NSMenuItem(title: "No recent picks", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      statusMenu.addItem(empty)
    } else {
      for text in recentPickTexts {
        let item = NSMenuItem(
          title: text,
          action: #selector(copyRecentPick(_:)),
          keyEquivalent: ""
        )
        item.representedObject = text
        statusMenu.addItem(item)
      }
    }

    statusMenu.addItem(NSMenuItem.separator())
    statusMenu.addItem(
      withTitle: "About ClrPkr",
      action: #selector(showAbout(_:)),
      keyEquivalent: ""
    )
    statusMenu.addItem(
      withTitle: "Quit ClrPkr",
      action: #selector(quitApp(_:)),
      keyEquivalent: "q"
    )
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
      case "updateMenu":
        let arguments = call.arguments as? [String: Any]
        let recentPicks = arguments?["recentPicks"] as? [[String: Any]] ?? []
        self.recentPickTexts = recentPicks.compactMap { pick in
          pick["copyText"] as? String
        }
        self.rebuildStatusMenu()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
