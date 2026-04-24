import AppKit
import SwiftUI

final class MainWindow: NSWindow, NSToolbarDelegate {
  private enum ToolbarIdentifier {
    static let main = NSToolbar.Identifier("com.kharion.clrpkr.main-toolbar")
    static let onTop = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.on-top")
    static let importItem = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.import")
    static let pick = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.pick")
    static let spacer = NSToolbarItem.Identifier.flexibleSpace
  }

  let store = ClrPkrStore()
  private weak var pinToolbarItem: NSToolbarItem?
  private weak var countLabel: NSTextField?
  private var titleAccessoryController: NSTitlebarAccessoryViewController?
  private weak var pinToolbarButton: NSButton?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func awakeFromNib() {
    let rootView = MainWindowRootView(store: store)
    let hostingController = NSHostingController(rootView: rootView)
    let windowFrame = frame
    contentViewController = hostingController
    setFrame(windowFrame, display: true)

    configureWindow()

    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.configureMainWindow(window: self)
    }

    super.awakeFromNib()
  }

  private func configureWindow() {
    styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    title = "ClrPkr"
    updateTitlebarCount(store.history.count)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    backgroundColor = .windowBackgroundColor
    isOpaque = false
    hasShadow = true
    setContentSize(NSSize(width: 420, height: 500))
    minSize = NSSize(width: 380, height: 380)
    standardWindowButton(.miniaturizeButton)?.isEnabled = false
    standardWindowButton(.zoomButton)?.isEnabled = false
    setupTitleAccessory()
    setupToolbar()
    center()

    if #available(macOS 11.0, *) {
      toolbarStyle = .unified
      titlebarSeparatorStyle = .none
    }

    DispatchQueue.main.async { [weak self] in
      self?.suppressControlFocusRings()
    }
  }

  func syncToolbarState() {
    pinToolbarItem?.image = toolbarImage(systemName: store.alwaysOnTop ? "pin.fill" : "pin")
    pinToolbarItem?.toolTip = store.alwaysOnTop ? "Disable On Top" : "Enable On Top"
    pinToolbarButton?.image = toolbarImage(systemName: store.alwaysOnTop ? "pin.fill" : "pin")
  }

  func updateTitlebarCount(_ count: Int) {
    countLabel?.stringValue = count == 1 ? "1 pick" : "\(count) picks"
  }

  @objc
  private func handleToolbarToggleOnTop(_ sender: Any?) {
    store.requestAlwaysOnTopToggle()
  }

  @objc
  private func handleToolbarImport(_ sender: Any?) {
    store.requestImport()
  }

  @objc
  private func handleToolbarPick(_ sender: Any?) {
    store.requestPick()
  }

  private func toolbarImage(systemName: String, tintColor: NSColor? = nil) -> NSImage? {
    guard let image = PlatformSymbol.image(systemName: systemName) else {
      return nil
    }

    guard let tintColor else {
      return image
    }

    let tintedImage = image.copy() as? NSImage ?? image
    tintedImage.lockFocus()
    defer { tintedImage.unlockFocus() }

    tintColor.set()
    NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
    tintedImage.isTemplate = false
    return tintedImage
  }

  private func setupToolbar() {
    let toolbar = NSToolbar(identifier: ToolbarIdentifier.main)
    toolbar.delegate = self
    toolbar.displayMode = .iconAndLabel
    toolbar.sizeMode = .regular
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    self.toolbar = toolbar
    syncToolbarState()
  }

  private func setupTitleAccessory() {
    guard titleAccessoryController == nil else { return }

    let titleLabel = NSTextField(labelWithString: "ClrPkr")
    titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
    titleLabel.textColor = .labelColor
    titleLabel.lineBreakMode = .byTruncatingTail

    let countLabel = NSTextField(labelWithString: "")
    countLabel.font = .systemFont(ofSize: 10, weight: .regular)
    countLabel.textColor = .secondaryLabelColor
    countLabel.lineBreakMode = .byTruncatingTail
    self.countLabel = countLabel

    let stack = NSStackView(views: [titleLabel, countLabel])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 0
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    let container = NSView(frame: NSRect(x: 0, y: 0, width: 74, height: 28))
    container.translatesAutoresizingMaskIntoConstraints = false
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)

    NSLayoutConstraint.activate([
      container.widthAnchor.constraint(equalToConstant: 74),
      container.heightAnchor.constraint(equalToConstant: 28),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])

    let accessory = NSTitlebarAccessoryViewController()
    accessory.view = container
    accessory.layoutAttribute = .left
    addTitlebarAccessoryViewController(accessory)
    titleAccessoryController = accessory

    updateTitlebarCount(store.history.count)
  }

  private func suppressControlFocusRings() {
    if let rootView = standardWindowButton(.closeButton)?.superview?.superview {
      suppressFocusRings(in: rootView)
    }

    if let contentView {
      suppressFocusRings(in: contentView)
    }
  }

  private func suppressFocusRings(in rootView: NSView) {
    if let button = rootView as? NSButton {
      button.focusRingType = .none
    }

    for subview in rootView.subviews {
      suppressFocusRings(in: subview)
    }
  }

  private func makeToolbarItem(
    identifier: NSToolbarItem.Identifier,
    label: String,
    symbolName: String,
    action: Selector,
    tintColor: NSColor? = nil
  ) -> NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: identifier)
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    item.image = toolbarImage(systemName: symbolName, tintColor: tintColor)
    item.visibilityPriority = .high

    let button = NSButton(image: toolbarImage(systemName: symbolName, tintColor: tintColor) ?? NSImage(), target: self, action: action)
    button.bezelStyle = .texturedRounded
    button.isBordered = true
    button.imagePosition = .imageOnly
    button.focusRingType = .none
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setButtonType(.momentaryPushIn)

    let titleLabel = NSTextField(labelWithString: label)
    titleLabel.font = .systemFont(ofSize: 10, weight: .regular)
    titleLabel.textColor = .secondaryLabelColor
    titleLabel.alignment = .center
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    let stack = NSStackView(views: [button, titleLabel])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 1
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    let container = NSView(frame: NSRect(x: 0, y: 0, width: 48, height: 36))
    container.translatesAutoresizingMaskIntoConstraints = false
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)

    NSLayoutConstraint.activate([
      container.widthAnchor.constraint(equalToConstant: 48),
      container.heightAnchor.constraint(equalToConstant: 36),
      stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      button.widthAnchor.constraint(greaterThanOrEqualToConstant: 24)
    ])

    item.view = container

    if identifier == ToolbarIdentifier.onTop {
      pinToolbarItem = item
      pinToolbarButton = button
    }

    return item
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [ToolbarIdentifier.spacer, ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [ToolbarIdentifier.spacer, ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    switch itemIdentifier {
    case ToolbarIdentifier.onTop:
      return makeToolbarItem(
        identifier: itemIdentifier,
        label: "On Top",
        symbolName: store.alwaysOnTop ? "pin.fill" : "pin",
        action: #selector(handleToolbarToggleOnTop(_:))
      )
    case ToolbarIdentifier.importItem:
      return makeToolbarItem(
        identifier: itemIdentifier,
        label: "Import",
        symbolName: "folder.badge.plus",
        action: #selector(handleToolbarImport(_:))
      )
    case ToolbarIdentifier.pick:
      return makeToolbarItem(
        identifier: itemIdentifier,
        label: "Pick",
        symbolName: "eyedropper.full",
        action: #selector(handleToolbarPick(_:)),
        tintColor: .controlAccentColor
      )
    default:
      return nil
    }
  }
}
