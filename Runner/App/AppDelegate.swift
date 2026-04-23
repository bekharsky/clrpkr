import Cocoa

final class StatusBarController: NSObject {
  private let onPick: () -> Void
  private let onShow: () -> Void
  private let onAbout: () -> Void
  private let onQuit: () -> Void
  private let onCopy: (String) -> Void

  private var statusItem: NSStatusItem?
  private let statusMenu = NSMenu()
  private var recentPickItems: [RecentPickMenuItem] = []

  init(
    onPick: @escaping () -> Void,
    onShow: @escaping () -> Void,
    onAbout: @escaping () -> Void,
    onQuit: @escaping () -> Void,
    onCopy: @escaping (String) -> Void
  ) {
    self.onPick = onPick
    self.onShow = onShow
    self.onAbout = onAbout
    self.onQuit = onQuit
    self.onCopy = onCopy
    super.init()
  }

  func install() {
    if statusItem == nil {
      statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }

    rebuildMenu()

    guard let button = statusItem?.button else {
      return
    }

    if #available(macOS 11.0, *),
       let symbol = NSImage(
        systemSymbolName: "eyedropper.full",
        accessibilityDescription: "ClrPkr"
       )?.withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
       ) {
      button.image = symbol
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
    statusItem?.length = button.image != nil && button.title.isEmpty
      ? NSStatusItem.squareLength
      : max(button.fittingSize.width + 4, NSStatusItem.squareLength)
    statusItem?.menu = statusMenu
  }

  func updateRecentPicks(_ picks: [RecentPickMenuItem]) {
    recentPickItems = Array(picks.prefix(10))
    rebuildMenu()
  }

  private func rebuildMenu() {
    statusMenu.removeAllItems()

    let showItem = NSMenuItem(title: "Show Window", action: #selector(handleShow), keyEquivalent: "")
    showItem.target = self
    let pickItem = NSMenuItem(title: "Pick Color", action: #selector(handlePick), keyEquivalent: "")
    pickItem.target = self
    statusMenu.addItem(showItem)
    statusMenu.addItem(pickItem)
    statusMenu.addItem(NSMenuItem.separator())

    if recentPickItems.isEmpty {
      let empty = NSMenuItem(title: "No recent picks", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      statusMenu.addItem(empty)
    } else {
      for recentPick in recentPickItems {
        let item = NSMenuItem(title: recentPick.text, action: #selector(handleCopy(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = recentPick.text
        item.image = makeSwatchImage(color: recentPick.color)
        statusMenu.addItem(item)
      }
    }

    statusMenu.addItem(NSMenuItem.separator())

    let aboutItem = NSMenuItem(title: "About ClrPkr", action: #selector(handleAbout), keyEquivalent: "")
    aboutItem.target = self
    statusMenu.addItem(aboutItem)

    let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
    quitItem.target = self
    statusMenu.addItem(quitItem)
  }

  @objc
  private func handlePick() {
    onPick()
  }

  @objc
  private func handleShow() {
    onShow()
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

  private func makeSwatchImage(color: NSColor) -> NSImage {
    let size = NSSize(width: 12, height: 12)
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
    let path = NSBezierPath(ovalIn: rect)
    color.setFill()
    path.fill()
    NSColor.black.withAlphaComponent(0.10).setStroke()
    path.lineWidth = 0.5
    path.stroke()
    image.isTemplate = false
    return image
  }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  @IBOutlet weak var applicationMenu: NSMenu!
  @IBOutlet weak var mainWindow: MainWindow!

  private var isMainWindowAlwaysOnTop = false
  private var hasRequestedScreenCaptureAccessThisLaunch = false
  private weak var historyController: ColorHistoryViewController?
  private lazy var screenColorPicker = ScreenColorPicker(
    hideWindow: { [weak self] in
      self?.hideMainWindow()
    },
    showWindow: { [weak self] in
      self?.showMainWindow()
    },
    onPick: { [weak self] payload in
      self?.handlePickedColor(payload)
    }
  )
  private lazy var statusBarController = StatusBarController(
    onPick: { [weak self] in
      self?.startPickerFromToolbar(nil)
    },
    onShow: { [weak self] in
      self?.showMainWindow()
    },
    onAbout: { [weak self] in
      self?.showAbout(nil)
    },
    onQuit: { [weak self] in
      self?.quitApp(nil)
    },
    onCopy: { [weak self] text in
      self?.copyText(text)
    }
  )

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureApplicationIcon()
    configureApplicationMenu()
    refreshStatusBar()
    DispatchQueue.main.async { [weak self] in
      self?.showMainWindow()
      self?.requestScreenCaptureAccessIfNeeded()
    }
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    refreshStatusBar()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    hideMainWindow()
    return false
  }

  func configureMainWindow(window: NSWindow, controller: ColorHistoryViewController) {
    window.delegate = self
    historyController = controller
    controller.setAlwaysOnTop(isMainWindowAlwaysOnTop)
    applyMainWindowLevel()
    refreshStatusBar()
    controller.onRecentPicksChanged = { [weak self] picks in
      self?.statusBarController.updateRecentPicks(picks)
    }
    statusBarController.updateRecentPicks(controller.currentRecentPickItems())
  }

  private func configureApplicationMenu() {
    let aboutIndex = applicationMenu.items.firstIndex { $0.title.contains("About") } ?? 0

    let pickItem = NSMenuItem(
      title: "Pick Color",
      action: #selector(startPickerFromToolbar(_:)),
      keyEquivalent: "p"
    )
    pickItem.keyEquivalentModifierMask = [.command]
    pickItem.target = self

    let hideWindowItem = NSMenuItem(
      title: "Hide Window",
      action: #selector(hideWindowCommand(_:)),
      keyEquivalent: "w"
    )
    hideWindowItem.keyEquivalentModifierMask = [.command]
    hideWindowItem.target = self

    applicationMenu.insertItem(pickItem, at: aboutIndex + 1)
    applicationMenu.insertItem(NSMenuItem.separator(), at: aboutIndex + 2)

    if let hideIndex = applicationMenu.items.firstIndex(where: { $0.keyEquivalent == "h" }) {
      let hideItem = applicationMenu.items[hideIndex]
      hideItem.title = "Hide Window"
      hideItem.action = #selector(hideWindowCommand(_:))
      hideItem.target = self
    }

    if let quitIndex = applicationMenu.items.firstIndex(where: { $0.keyEquivalent == "q" }) {
      let quitItem = applicationMenu.items[quitIndex]
      quitItem.action = #selector(quitApp(_:))
      quitItem.target = self
    }

    applicationMenu.insertItem(hideWindowItem, at: max(aboutIndex + 3, applicationMenu.numberOfItems - 2))
  }

  @objc
  private func quitApp(_ sender: Any?) {
    NSApp.terminate(nil)
  }

  @objc
  private func hideWindowCommand(_ sender: Any?) {
    hideMainWindow()
  }

  @objc
  private func showAbout(_ sender: Any?) {
    var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
    if let icon = resolvedApplicationIcon() {
      options[.applicationIcon] = icon
    }
    NSApp.orderFrontStandardAboutPanel(options)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc
  func startPickerFromToolbar(_ sender: Any?) {
    screenColorPicker.start()
  }

  @objc
  func importImagesFromToolbar(_ sender: Any?) {
    guard let controller = historyController ?? mainWindow?.historyViewController else {
      return
    }

    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.resolvesAliases = true
    panel.prompt = "Import"
    panel.message = "Choose image files or folders to build imported palettes."

    let nestedFoldersButton = NSButton(checkboxWithTitle: "Analyze nested folders", target: nil, action: nil)
    nestedFoldersButton.state = .off
    panel.accessoryView = nestedFoldersButton

    let previousPolicy = NSApp.activationPolicy()
    let switchedToRegular = previousPolicy != .regular && NSApp.setActivationPolicy(.regular)

    showMainWindow()
    NSApp.activate(ignoringOtherApps: true)

    if panel.runModal() == .OK {
      controller.importSelectedItems(
        at: panel.urls,
        includesNestedFolders: nestedFoldersButton.state == .on
      )
    }

    if switchedToRegular {
      DispatchQueue.main.async {
        NSApp.setActivationPolicy(previousPolicy)
      }
    }
  }

  @objc
  func toggleAlwaysOnTopFromToolbar(_ sender: Any?) {
    isMainWindowAlwaysOnTop.toggle()
    historyController?.setAlwaysOnTop(isMainWindowAlwaysOnTop)
    applyMainWindowLevel()
  }

  private func handlePickedColor(_ payload: PickedColorPayload) {
    historyController?.addPick(
      red: payload.red,
      green: payload.green,
      blue: payload.blue,
      previewPng: payload.previewPng
    )
  }

  private func copyText(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  private func configureApplicationIcon() {
    guard let icon = resolvedApplicationIcon() else {
      return
    }
    NSApp.applicationIconImage = icon
  }

  private func resolvedApplicationIcon() -> NSImage? {
    if let resourcePath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
       let icon = NSImage(contentsOfFile: resourcePath) {
      return icon
    }

    return NSImage(named: "AppIcon")
  }

  private func showMainWindow() {
    guard let window = mainWindow else {
      return
    }

    applyMainWindowLevel()
    NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
    window.makeKeyAndOrderFront(nil)
  }

  private func hideMainWindow() {
    mainWindow?.orderOut(nil)
  }

  private func applyMainWindowLevel() {
    guard let window = mainWindow else {
      return
    }

    window.level = isMainWindowAlwaysOnTop ? .floating : .normal
  }

  private func refreshStatusBar() {
    DispatchQueue.main.async { [weak self] in
      self?.statusBarController.install()
    }
  }

  private func requestScreenCaptureAccessIfNeeded() {
    guard !hasRequestedScreenCaptureAccessThisLaunch else {
      return
    }

    hasRequestedScreenCaptureAccessThisLaunch = true

    guard #available(macOS 10.15, *) else {
      return
    }

    guard !CGPreflightScreenCaptureAccess() else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    _ = CGRequestScreenCaptureAccess()
  }
}
