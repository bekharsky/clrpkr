import AppKit
import SwiftUI

final class MainWindow: NSWindow, NSToolbarDelegate {
  private enum ToolbarIdentifier {
    static let main = NSToolbar.Identifier("com.kharion.clrpkr.main-toolbar")
    static let onTop = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.on-top")
    static let importItem = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.import")
    static let pick = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.pick")
  }

  let store = ClrPkrStore()
  private weak var pinToolbarItem: NSToolbarItem?

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
    titleVisibility = .visible
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    backgroundColor = .windowBackgroundColor
    isOpaque = false
    hasShadow = true
    setContentSize(NSSize(width: 420, height: 500))
    minSize = NSSize(width: 380, height: 380)
    standardWindowButton(.miniaturizeButton)?.isEnabled = false
    standardWindowButton(.zoomButton)?.isEnabled = false
    setupToolbar()
    center()

    if #available(macOS 11.0, *) {
      toolbarStyle = .unified
      titlebarSeparatorStyle = .none
    }
  }

  func syncToolbarState() {
    pinToolbarItem?.image = toolbarImage(systemName: store.alwaysOnTop ? "pin.fill" : "pin")
    pinToolbarItem?.toolTip = store.alwaysOnTop ? "Disable On Top" : "Enable On Top"
  }

  func updateTitlebarCount(_ count: Int) {
    if #available(macOS 11.0, *) {
      subtitle = count == 1 ? "1 pick" : "\(count) picks"
    }
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
    if #available(macOS 13.0, *) {
      toolbar.centeredItemIdentifiers = [ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
    }
    self.toolbar = toolbar
    syncToolbarState()
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
    item.target = self
    item.action = action
    item.isBordered = true
    item.visibilityPriority = .high

    if identifier == ToolbarIdentifier.onTop {
      pinToolbarItem = item
    }

    return item
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
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
