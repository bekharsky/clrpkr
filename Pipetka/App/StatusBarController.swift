import Cocoa

final class StatusBarController: NSObject {
  private let onPick: () -> Void
  private let onShow: () -> Void
  private let onShowWindowAfterPickChange: (Bool) -> Void
  private let onLaunchAtLoginChange: (Bool) -> Void
  private let onAbout: () -> Void
  private let onQuit: () -> Void
  private let onCopy: (String) -> Void

  private var statusItem: NSStatusItem?
  private let statusMenu = NSMenu()
  private var recentPickItems: [RecentPickMenuItem] = []
  private var showsWindowAfterPick: Bool
  private var isLaunchAtLoginEnabled: Bool
  private var isInstalled = false

  init(
    onPick: @escaping () -> Void,
    onShow: @escaping () -> Void,
    showsWindowAfterPick: Bool,
    onShowWindowAfterPickChange: @escaping (Bool) -> Void,
    isLaunchAtLoginEnabled: Bool,
    onLaunchAtLoginChange: @escaping (Bool) -> Void,
    onAbout: @escaping () -> Void,
    onQuit: @escaping () -> Void,
    onCopy: @escaping (String) -> Void
  ) {
    self.onPick = onPick
    self.onShow = onShow
    self.showsWindowAfterPick = showsWindowAfterPick
    self.onShowWindowAfterPickChange = onShowWindowAfterPickChange
    self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
    self.onLaunchAtLoginChange = onLaunchAtLoginChange
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
        accessibilityDescription: "Pipetka"
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
    button.toolTip = "Pipetka"
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

  func setShowsWindowAfterPick(_ value: Bool) {
    showsWindowAfterPick = value
    rebuildMenu()
  }

  func setLaunchAtLoginEnabled(_ value: Bool) {
    isLaunchAtLoginEnabled = value
    rebuildMenu()
  }

  private func rebuildMenu() {
    statusMenu.removeAllItems()

    let showItem = NSMenuItem(title: "Show Window", action: #selector(handleShow), keyEquivalent: "")
    showItem.target = self
    let pickItem = NSMenuItem(title: "Pick Color", action: #selector(handlePick), keyEquivalent: "")
    pickItem.target = self
    let showAfterPickItem = NSMenuItem(
      title: "Show Window After Pick",
      action: #selector(handleShowWindowAfterPickToggle),
      keyEquivalent: ""
    )
    showAfterPickItem.target = self
    showAfterPickItem.state = showsWindowAfterPick ? .on : .off
    let launchAtLoginItem = NSMenuItem(
      title: "Launch at Login",
      action: #selector(handleLaunchAtLoginToggle),
      keyEquivalent: ""
    )
    launchAtLoginItem.target = self
    launchAtLoginItem.state = isLaunchAtLoginEnabled ? .on : .off
    statusMenu.addItem(showItem)
    statusMenu.addItem(pickItem)
    statusMenu.addItem(showAfterPickItem)
    statusMenu.addItem(launchAtLoginItem)
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

    let aboutItem = NSMenuItem(title: "About Pipetka", action: #selector(handleAbout), keyEquivalent: "")
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
  private func handleShowWindowAfterPickToggle() {
    showsWindowAfterPick.toggle()
    onShowWindowAfterPickChange(showsWindowAfterPick)
    rebuildMenu()
  }

  @objc
  private func handleLaunchAtLoginToggle() {
    onLaunchAtLoginChange(!isLaunchAtLoginEnabled)
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
