import Cocoa
import FlutterMacOS

private let pickerToolbarItemIdentifier = NSToolbarItem.Identifier("com.clrpkr.pick")

class MainFlutterWindow: NSWindow, NSToolbarDelegate {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.configureFlutterBindings(
        flutterViewController: flutterViewController,
        window: self
      )
    }

    let toolbar = NSToolbar(identifier: "ClrPkrToolbar")
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.allowsUserCustomization = false
    self.toolbar = toolbar
    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unified
    }

    title = "ClrPkr"
    titleVisibility = .visible
    titlebarAppearsTransparent = false
    isMovableByWindowBackground = false
    backgroundColor = NSColor.windowBackgroundColor
    setContentSize(NSSize(width: 360, height: 470))
    minSize = NSSize(width: 330, height: 380)
    center()

    super.awakeFromNib()
  }
  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [pickerToolbarItemIdentifier, .flexibleSpace]
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [pickerToolbarItemIdentifier]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard itemIdentifier == pickerToolbarItemIdentifier else {
      return nil
    }

    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.toolTip = "Pick color from screen"

    let button = NSButton(
      title: "",
      target: NSApp.delegate,
      action: #selector(AppDelegate.startPickerFromToolbar(_:))
    )
    button.bezelStyle = .texturedRounded
    button.isBordered = true
    button.imagePosition = .imageOnly
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "eyedropper.full",
        accessibilityDescription: "Pick"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
      button.image = image?.withSymbolConfiguration(config)
      button.image?.isTemplate = true
    }
    button.toolTip = "Pick color from screen"
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: 40),
      button.heightAnchor.constraint(equalToConstant: 32),
    ])
    item.label = ""
    item.paletteLabel = "Pick"
    item.minSize = NSSize(width: 40, height: 32)
    item.maxSize = NSSize(width: 40, height: 32)
    item.view = button
    item.visibilityPriority = .high
    return item
  }
}
