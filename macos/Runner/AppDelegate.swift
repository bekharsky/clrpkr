import Cocoa
import FlutterMacOS

final class StatusBarController: NSObject {
  private let onPick: () -> Void
  private let onAbout: () -> Void
  private let onQuit: () -> Void
  private let onCopy: (String) -> Void

  private var statusItem: NSStatusItem?
  private let statusMenu = NSMenu()
  private var recentPickTexts: [String] = []

  init(
    onPick: @escaping () -> Void,
    onAbout: @escaping () -> Void,
    onQuit: @escaping () -> Void,
    onCopy: @escaping (String) -> Void
  ) {
    self.onPick = onPick
    self.onAbout = onAbout
    self.onQuit = onQuit
    self.onCopy = onCopy
    super.init()
  }

  func install() {
    if statusItem == nil {
      statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    }

    rebuildMenu()

    guard let button = statusItem?.button else {
      return
    }

    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "eyedropper.full",
        accessibilityDescription: "ClrPkr"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
      button.image = image?.withSymbolConfiguration(config)
      button.image?.isTemplate = true
      button.title = ""
      button.imagePosition = .imageOnly
    } else {
      button.title = "PK"
      button.image = nil
      button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
      button.imagePosition = .noImage
    }

    button.isHidden = false
    button.appearsDisabled = false
    button.toolTip = "ClrPkr"
    button.sizeToFit()
    statusItem?.isVisible = true
    statusItem?.menu = statusMenu
  }

  func updateRecentPicks(_ picks: [String]) {
    recentPickTexts = Array(picks.prefix(10))
    rebuildMenu()
  }

  private func rebuildMenu() {
    statusMenu.removeAllItems()

    let pickItem = NSMenuItem(title: "Pick", action: #selector(handlePick), keyEquivalent: "")
    pickItem.target = self
    statusMenu.addItem(pickItem)
    statusMenu.addItem(NSMenuItem.separator())

    if recentPickTexts.isEmpty {
      let empty = NSMenuItem(title: "No recent picks", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      statusMenu.addItem(empty)
    } else {
      for text in recentPickTexts {
        let item = NSMenuItem(title: text, action: #selector(handleCopy(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = text
        statusMenu.addItem(item)
      }
    }

    statusMenu.addItem(NSMenuItem.separator())

    let aboutItem = NSMenuItem(title: "About ClrPkr", action: #selector(handleAbout), keyEquivalent: "")
    aboutItem.target = self
    statusMenu.addItem(aboutItem)

    let quitItem = NSMenuItem(title: "Quit ClrPkr", action: #selector(handleQuit), keyEquivalent: "q")
    quitItem.target = self
    statusMenu.addItem(quitItem)
  }

  @objc
  private func handlePick() {
    onPick()
  }

  @objc
  private func handleAbout() {
    onAbout()
  }

  @objc
  private func handleQuit() {
    onQuit()
  }

  @objc
  private func handleCopy(_ sender: NSMenuItem) {
    guard let text = sender.representedObject as? String else {
      return
    }
    onCopy(text)
  }
}

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate, FlutterStreamHandler {
  private var pickEventSink: FlutterEventSink?
  private var pickerBridge: ScreenColorPickerBridge?
  private var channelsConfigured = false
  private lazy var statusBarController = StatusBarController(
    onPick: { [weak self] in
      self?.startPickerFromToolbar(nil)
    },
    onAbout: { [weak self] in
      self?.showAbout(nil)
    },
    onQuit: { [weak self] in
      self?.quitApp(nil)
    },
    onCopy: { [weak self] text in
      self?.copyRecentPickText(text)
    }
  )

  override init() {
    super.init()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidFinishLaunchingNotification(_:)),
      name: NSApplication.didFinishLaunchingNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActiveNotification(_:)),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc
  private func handleDidFinishLaunchingNotification(_ notification: Notification) {
    statusBarController.install()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      self?.statusBarController.install()
    }
  }

  @objc
  private func handleDidBecomeActiveNotification(_ notification: Notification) {
    DispatchQueue.main.async { [weak self] in
      self?.statusBarController.install()
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
  private func copyRecentPickText(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
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
        let recentPickTexts = recentPicks.compactMap { pick in
          pick["copyText"] as? String
        }
        self.statusBarController.updateRecentPicks(recentPickTexts)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
