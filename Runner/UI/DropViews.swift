import Cocoa

class NativePanelView: NSView {
  private let dropOverlayView = DropOverlayView()
  private let dropIconView = NSImageView()
  private let dropLabel = NSTextField(labelWithString: "Drop image here to extract a palette")
  private let dropHintLabel = NSTextField(labelWithString: "We’ll pull dominant colors into Imported Palette")
  private var isDropTargetActive = false {
    didSet { needsDisplay = true }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupDropHandling()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupDropHandling()
  }

  private func setupDropHandling() {
    wantsLayer = true
    layer?.cornerRadius = 14
    layer?.masksToBounds = true
    dropOverlayView.translatesAutoresizingMaskIntoConstraints = false
    dropOverlayView.isHidden = true
    addSubview(dropOverlayView)
    NSLayoutConstraint.activate([
      dropOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
      dropOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
      dropOverlayView.topAnchor.constraint(equalTo: topAnchor),
      dropOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "photo.on.rectangle.angled",
        accessibilityDescription: "Import image palette"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 26, weight: .medium)
      dropIconView.image = image?.withSymbolConfiguration(config)
      dropIconView.image?.isTemplate = true
      dropIconView.contentTintColor = NSColor(
        srgbRed: 0.18,
        green: 0.43,
        blue: 0.79,
        alpha: 1
      )
    }
    dropIconView.alphaValue = 0
    dropIconView.translatesAutoresizingMaskIntoConstraints = false
    dropOverlayView.addSubview(dropIconView)

    dropLabel.alignment = .center
    dropLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
    dropLabel.textColor = NSColor(
      srgbRed: 0.22,
      green: 0.39,
      blue: 0.62,
      alpha: 1
    )
    dropLabel.alphaValue = 0
    dropLabel.translatesAutoresizingMaskIntoConstraints = false
    dropOverlayView.addSubview(dropLabel)

    dropHintLabel.alignment = .center
    dropHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    dropHintLabel.textColor = NSColor(
      srgbRed: 0.32,
      green: 0.46,
      blue: 0.61,
      alpha: 1
    )
    dropHintLabel.alphaValue = 0
    dropHintLabel.translatesAutoresizingMaskIntoConstraints = false
    dropOverlayView.addSubview(dropHintLabel)

    NSLayoutConstraint.activate([
      dropIconView.centerXAnchor.constraint(equalTo: dropOverlayView.centerXAnchor),
      dropIconView.centerYAnchor.constraint(equalTo: dropOverlayView.centerYAnchor, constant: -20),
      dropLabel.centerXAnchor.constraint(equalTo: dropOverlayView.centerXAnchor),
      dropLabel.topAnchor.constraint(equalTo: dropIconView.bottomAnchor, constant: 10),
      dropHintLabel.centerXAnchor.constraint(equalTo: dropOverlayView.centerXAnchor),
      dropHintLabel.topAnchor.constraint(equalTo: dropLabel.bottomAnchor, constant: 4)
    ])
  }

  func setDropTargetActive(_ active: Bool) {
    guard isDropTargetActive != active else {
      return
    }

    isDropTargetActive = active
    dropOverlayView.isHidden = false
    addSubview(dropOverlayView, positioned: .above, relativeTo: nil)
    dropOverlayView.setHighlighted(active)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.12
      dropIconView.animator().alphaValue = active ? 1 : 0
      dropLabel.animator().alphaValue = active ? 1 : 0
      dropHintLabel.animator().alphaValue = active ? 1 : 0
    } completionHandler: {
      self.dropOverlayView.isHidden = !active
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
    let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
    NSColor(calibratedWhite: 0.99, alpha: 1).setFill()
    path.fill()
    NSColor(calibratedWhite: 0, alpha: 0.07).setStroke()
    path.lineWidth = 1
    path.stroke()
  }
}

final class DropOverlayView: NSView {
  private var isHighlighted = false {
    didSet { needsDisplay = true }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  func setHighlighted(_ highlighted: Bool) {
    isHighlighted = highlighted
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    guard isHighlighted else {
      return
    }

    let coverPath = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
    NSColor(
      srgbRed: 0.93,
      green: 0.97,
      blue: 1.0,
      alpha: 1
    ).setFill()
    coverPath.fill()

    let highlightRect = bounds.insetBy(dx: 6, dy: 6)
    let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 12, yRadius: 12)
    NSColor(
      srgbRed: 0.85,
      green: 0.93,
      blue: 1.0,
      alpha: 1
    ).setFill()
    highlightPath.fill()

    let dashPattern: [CGFloat] = [7, 6]
    NSColor(
      srgbRed: 0.13,
      green: 0.46,
      blue: 0.92,
      alpha: 0.55
    ).setStroke()
    highlightPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
    highlightPath.lineWidth = 2
    highlightPath.stroke()
  }
}

final class WholeWindowDropView: NSView {
  private static let supportedDragTypes: [NSPasteboard.PasteboardType] = [.fileURL, .tiff]
  var onDropImage: ((NSImage) -> Void)?
  var onDropStateChanged: ((Bool) -> Void)?

  var wantsPeriodicDraggingUpdates: Bool {
    true
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes(Self.supportedDragTypes)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes(Self.supportedDragTypes)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard canAccept(sender.draggingPasteboard) else {
      return []
    }

    onDropStateChanged?(true)
    return .copy
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard canAccept(sender.draggingPasteboard) else {
      onDropStateChanged?(false)
      return []
    }

    onDropStateChanged?(true)
    return .copy
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    onDropStateChanged?(false)
  }

  override func draggingEnded(_ sender: NSDraggingInfo) {
    onDropStateChanged?(false)
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    canAccept(sender.draggingPasteboard)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    defer {
      onDropStateChanged?(false)
    }

    guard let image = image(from: sender.draggingPasteboard) else {
      return false
    }

    onDropImage?(image)
    return true
  }

  override func concludeDragOperation(_ sender: NSDraggingInfo?) {
    onDropStateChanged?(false)
  }

  private func canAccept(_ pasteboard: NSPasteboard) -> Bool {
    if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
      return true
    }

    return pasteboard.data(forType: .tiff) != nil
  }

  private func image(from pasteboard: NSPasteboard) -> NSImage? {
    if
      let items = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
      let imageURL = items.first(where: { NSImage(contentsOf: $0) != nil })
    {
      return NSImage(contentsOf: imageURL)
    }

    if let data = pasteboard.data(forType: .tiff) {
      return NSImage(data: data)
    }

    return nil
  }
}

final class AspectFillImageView: NSView {
  var image: NSImage? {
    didSet { needsDisplay = true }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.cornerRadius = 8
    layer?.masksToBounds = true
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
    layer?.cornerRadius = 8
    layer?.masksToBounds = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let boundsPath = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
    NSColor(
      srgbRed: 0.94,
      green: 0.95,
      blue: 0.97,
      alpha: 1
    ).setFill()
    boundsPath.fill()

    guard let image else {
      return
    }

    let imageSize = image.size
    guard imageSize.width > 0, imageSize.height > 0 else {
      return
    }

    let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
    let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let drawRect = NSRect(
      x: bounds.midX - scaledSize.width / 2,
      y: bounds.midY - scaledSize.height / 2,
      width: scaledSize.width,
      height: scaledSize.height
    )
    image.draw(in: drawRect)
  }
}
