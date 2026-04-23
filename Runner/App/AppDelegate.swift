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
  private var isInstalled = false

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
    if isInstalled {
      rebuildMenu()
      statusItem?.menu = statusMenu
      return
    }

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
    isInstalled = true
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
  private var aboutWindowController: NSWindowController?
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
    }
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

  func configureMainWindow(window: MainWindow) {
    window.delegate = self
    window.store.setAlwaysOnTop(isMainWindowAlwaysOnTop)
    window.syncToolbarState()
    window.updateTitlebarCount(window.store.history.count)
    applyMainWindowLevel()
    window.store.onPickRequested = { [weak self] in
      self?.startPickerFromToolbar(nil)
    }
    window.store.onImportRequested = { [weak self] in
      self?.importImagesFromToolbar(nil)
    }
    window.store.onAlwaysOnTopToggleRequested = { [weak self] in
      self?.toggleAlwaysOnTopFromToolbar(nil)
    }
    window.store.onRecentPicksChanged = { [weak self] picks in
      self?.statusBarController.updateRecentPicks(picks)
      self?.mainWindow?.updateTitlebarCount(self?.mainWindow?.store.history.count ?? 0)
    }
    statusBarController.updateRecentPicks(window.store.currentRecentPickItems())
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
    let windowController = aboutWindowController ?? makeAboutWindowController()
    aboutWindowController = windowController
    windowController.showWindow(nil)
    windowController.window?.center()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc
  func startPickerFromToolbar(_ sender: Any?) {
    requestScreenCaptureAccessIfNeeded()
    screenColorPicker.start()
  }

  @objc
  func importImagesFromToolbar(_ sender: Any?) {
    guard
      let store = mainWindow?.store,
      let window = mainWindow
    else {
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

    showMainWindow()
    NSApp.activate(ignoringOtherApps: true)
    panel.beginSheetModal(for: window) { response in
      guard response == .OK else {
        return
      }

      store.importSelectedItems(
        at: panel.urls,
        includesNestedFolders: nestedFoldersButton.state == .on
      )
    }
  }

  @objc
  func toggleAlwaysOnTopFromToolbar(_ sender: Any?) {
    isMainWindowAlwaysOnTop.toggle()
    mainWindow?.store.setAlwaysOnTop(isMainWindowAlwaysOnTop)
    mainWindow?.syncToolbarState()
    applyMainWindowLevel()
  }

  private func handlePickedColor(_ payload: PickedColorPayload) {
    mainWindow?.store.addPick(
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

  private func makeAboutWindowController() -> NSWindowController {
    let contentSize = NSSize(width: 420, height: 320)
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "About ClrPkr"
    window.isReleasedWhenClosed = false
    window.center()

    let contentView = NSView(frame: NSRect(origin: .zero, size: contentSize))
    contentView.translatesAutoresizingMaskIntoConstraints = false
    window.contentView = contentView

    let iconView = NSImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.image = resolvedApplicationIcon()
    iconView.imageScaling = .scaleProportionallyUpOrDown

    let appNameLabel = NSTextField(labelWithString: "ClrPkr")
    appNameLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
    appNameLabel.alignment = .center

    let versionLabel = NSTextField(labelWithString: aboutVersionText())
    versionLabel.font = NSFont.systemFont(ofSize: 12)
    versionLabel.textColor = .secondaryLabelColor
    versionLabel.alignment = .center

    let authorLabel = NSTextField(labelWithString: "Author: Sergey Bekharskiy")
    authorLabel.font = NSFont.systemFont(ofSize: 12)
    authorLabel.textColor = .secondaryLabelColor
    authorLabel.alignment = .center

    let copyrightLabel = NSTextField(labelWithString: aboutCopyrightText())
    copyrightLabel.font = NSFont.systemFont(ofSize: 11)
    copyrightLabel.textColor = .secondaryLabelColor
    copyrightLabel.alignment = .center

    let attributionTitle = NSTextField(labelWithString: "Color naming")
    attributionTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

    let attributionLabel = NSTextField(wrappingLabelWithString: NamedColorLookup.aboutAttribution)
    attributionLabel.font = NSFont.systemFont(ofSize: 12)
    attributionLabel.textColor = .labelColor
    attributionLabel.maximumNumberOfLines = 0

    let stack = NSStackView(views: [
      iconView,
      appNameLabel,
      versionLabel,
      authorLabel,
      copyrightLabel,
      attributionTitle,
      attributionLabel
    ])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 10
    stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)

    attributionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    attributionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    attributionTitle.setContentHuggingPriority(.defaultLow, for: .horizontal)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      stack.topAnchor.constraint(equalTo: contentView.topAnchor),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 64),
      iconView.heightAnchor.constraint(equalToConstant: 64),
      attributionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 340)
    ])

    return NSWindowController(window: window)
  }

  private func aboutVersionText() -> String {
    let bundle = Bundle.main
    let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let buildVersion = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

    switch (shortVersion?.isEmpty == false ? shortVersion : nil, buildVersion?.isEmpty == false ? buildVersion : nil) {
    case let (short?, build?) where short != build:
      return "Version \(short) (\(build))"
    case let (short?, _):
      return "Version \(short)"
    case let (_, build?):
      return "Build \(build)"
    default:
      return "Color picker and palette utility"
    }
  }

  private func aboutCopyrightText() -> String {
    (Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nonEmpty ?? "Copyright © 2026 Kharion. All rights reserved."
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
    statusBarController.install()
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

private extension String {
  var nonEmpty: String? {
    isEmpty ? nil : self
  }
}
