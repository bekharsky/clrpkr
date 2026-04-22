import Cocoa

enum ColorFormat: Int, CaseIterable {
  case hex
  case rgb
  case hsl
  case swiftUI

  var label: String {
    switch self {
    case .hex:
      return "HEX"
    case .rgb:
      return "RGB"
    case .hsl:
      return "HSL"
    case .swiftUI:
      return "SwiftUI"
    }
  }
}

struct PickedColor {
  let id = UUID()
  let color: NSColor
  let previewImage: NSImage?
  let pickedAt: Date

  var rgbColor: NSColor {
    color.usingColorSpace(.deviceRGB) ?? color
  }

  var red: Int {
    Int(round(rgbColor.redComponent * 255))
  }

  var green: Int {
    Int(round(rgbColor.greenComponent * 255))
  }

  var blue: Int {
    Int(round(rgbColor.blueComponent * 255))
  }
}

struct RecentPickMenuItem {
  let text: String
  let color: NSColor
}

struct PaletteColorBucket {
  let color: NSColor
  let pixelCount: Int
}

enum ImagePaletteExtractor {
  static func extractPalette(from image: NSImage, maxColors: Int = 6) -> [PaletteColorBucket] {
    guard
      maxColors > 0,
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let bitmap = downsampledBitmap(from: cgImage)
    else {
      return []
    }

    struct BucketAccumulator {
      var count = 0
      var redTotal = 0
      var greenTotal = 0
      var blueTotal = 0
    }

    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh
    let quantizationShift = 3
    let minimumAlpha = 24
    var buckets: [UInt32: BucketAccumulator] = [:]

    for y in 0..<height {
      for x in 0..<width {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
          continue
        }

        let alpha = Int(round(color.alphaComponent * 255))
        guard alpha >= minimumAlpha else {
          continue
        }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        let key = UInt32(red >> quantizationShift) << 10
          | UInt32(green >> quantizationShift) << 5
          | UInt32(blue >> quantizationShift)

        var accumulator = buckets[key] ?? BucketAccumulator()
        accumulator.count += 1
        accumulator.redTotal += red
        accumulator.greenTotal += green
        accumulator.blueTotal += blue
        buckets[key] = accumulator
      }
    }

    let sortedBuckets = buckets.values.sorted { lhs, rhs in
      lhs.count > rhs.count
    }

    var palette: [PaletteColorBucket] = []
    for bucket in sortedBuckets {
      let color = NSColor(
        srgbRed: CGFloat(bucket.redTotal) / CGFloat(bucket.count * 255),
        green: CGFloat(bucket.greenTotal) / CGFloat(bucket.count * 255),
        blue: CGFloat(bucket.blueTotal) / CGFloat(bucket.count * 255),
        alpha: 1
      )

      let isTooCloseToExisting = palette.contains { existing in
        colorDistanceSquared(color, existing.color) < 36 * 36
      }
      guard !isTooCloseToExisting else {
        continue
      }

      palette.append(PaletteColorBucket(color: color, pixelCount: bucket.count))
      if palette.count == maxColors {
        break
      }
    }

    return palette
  }

  private static func downsampledBitmap(from image: CGImage) -> NSBitmapImageRep? {
    let maxDimension = 72

    if image.width <= maxDimension, image.height <= maxDimension {
      return NSBitmapImageRep(cgImage: image)
    }

    let width = max(1, min(maxDimension, image.width))
    let height = max(1, min(maxDimension, image.height))

    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      return nil
    }

    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let scaledImage = context.makeImage() else {
      return nil
    }

    return NSBitmapImageRep(cgImage: scaledImage)
  }

  private static func colorDistanceSquared(_ lhs: NSColor, _ rhs: NSColor) -> Int {
    let left = lhs.usingColorSpace(.deviceRGB) ?? lhs
    let right = rhs.usingColorSpace(.deviceRGB) ?? rhs
    let redDelta = Int(round((left.redComponent - right.redComponent) * 255))
    let greenDelta = Int(round((left.greenComponent - right.greenComponent) * 255))
    let blueDelta = Int(round((left.blueComponent - right.blueComponent) * 255))
    return redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta
  }
}

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

final class HeaderBarView: NSView {
  override var mouseDownCanMoveWindow: Bool {
    true
  }
}

final class TrafficLightButton: NSButton {
  private var trackingAreaRef: NSTrackingArea?
  private var isHovering = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    isBordered = false
    setButtonType(.momentaryChange)
    wantsLayer = true
    imagePosition = .imageOnly
    contentTintColor = NSColor.black.withAlphaComponent(0.55)
    alphaValue = 1
    focusRingType = .none
    layer?.masksToBounds = true
  }

  override func layout() {
    super.layout()
    layer?.cornerRadius = min(bounds.width, bounds.height) / 2
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingAreaRef {
      removeTrackingArea(trackingAreaRef)
    }

    let trackingAreaRef = NSTrackingArea(
      rect: .zero,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingAreaRef)
    self.trackingAreaRef = trackingAreaRef
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    isHovering = true
    updateAppearance()
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    isHovering = false
    updateAppearance()
  }

  override var isHighlighted: Bool {
    didSet {
      needsDisplay = true
    }
  }

  private func updateAppearance() {
    needsDisplay = true
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .arrow)
  }

  override func draw(_ dirtyRect: NSRect) {
    let circleRect = bounds.insetBy(dx: 0.5, dy: 0.5)
    let circlePath = NSBezierPath(ovalIn: circleRect)
    let fillColor = NSColor(
      srgbRed: isHighlighted ? 0.88 : 1.0,
      green: isHighlighted ? 0.29 : 0.37,
      blue: isHighlighted ? 0.25 : 0.33,
      alpha: 1
    )
    fillColor.setFill()
    circlePath.fill()

    NSColor.black.withAlphaComponent(0.12).setStroke()
    circlePath.lineWidth = 0.5
    circlePath.stroke()

    guard isHovering else {
      return
    }

    NSColor.black.withAlphaComponent(0.55).setStroke()
    let inset = bounds.width * 0.34
    let xPath = NSBezierPath()
    xPath.lineWidth = 1
    xPath.lineCapStyle = .round
    xPath.move(to: NSPoint(x: inset, y: inset))
    xPath.line(to: NSPoint(x: bounds.width - inset, y: bounds.height - inset))
    xPath.move(to: NSPoint(x: bounds.width - inset, y: inset))
    xPath.line(to: NSPoint(x: inset, y: bounds.height - inset))
    xPath.stroke()
  }
}

final class HeaderPickButton: NSButton {
  private var trackingAreaRef: NSTrackingArea?
  private var isHovering = false
  var isToggled = false {
    didSet {
      updateAppearance()
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    isBordered = false
    setButtonType(.momentaryChange)
    imagePosition = .imageOnly
    wantsLayer = true
    layer?.cornerRadius = 10
    updateAppearance()
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingAreaRef {
      removeTrackingArea(trackingAreaRef)
    }

    let trackingAreaRef = NSTrackingArea(
      rect: .zero,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingAreaRef)
    self.trackingAreaRef = trackingAreaRef
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    isHovering = true
    updateAppearance()
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    isHovering = false
    updateAppearance()
  }

  override var isHighlighted: Bool {
    didSet {
      updateAppearance()
    }
  }

  private func updateAppearance() {
    let background: NSColor
    let tint: NSColor

    if isHighlighted || isToggled {
      background = NSColor(
        srgbRed: 0.23,
        green: 0.58,
        blue: 0.98,
        alpha: 0.26
      )
      tint = NSColor(
        srgbRed: 0.05,
        green: 0.27,
        blue: 0.60,
        alpha: 1
      )
    } else if isHovering {
      background = NSColor(
        srgbRed: 0.23,
        green: 0.58,
        blue: 0.98,
        alpha: 0.14
      )
      tint = NSColor(
        srgbRed: 0.10,
        green: 0.35,
        blue: 0.74,
        alpha: 1
      )
    } else {
      background = .clear
      tint = NSColor(
        srgbRed: 0.31,
        green: 0.40,
        blue: 0.53,
        alpha: 1
      )
    }

    layer?.backgroundColor = background.cgColor
    layer?.borderWidth = isHovering || isHighlighted || isToggled ? 1 : 0
    layer?.borderColor = ((isHighlighted || isToggled)
      ? NSColor(
          srgbRed: 0.13,
          green: 0.46,
          blue: 0.92,
          alpha: 0.24
        )
      : NSColor(
          srgbRed: 0.13,
          green: 0.46,
          blue: 0.92,
          alpha: 0.16
        )
    ).cgColor
    contentTintColor = tint
    image?.isTemplate = true
  }
}

final class FormatPickerView: NSView {
  var onChange: ((ColorFormat) -> Void)?
  private(set) var selectedFormat: ColorFormat = .hex

  private let hoverView = NSView()
  private let indicatorView = NSView()
  private var showsKeyboardFocusRing = false
  private var hoveredIndex: Int?
  private var trackingAreaRef: NSTrackingArea?
  private let buttons: [NSButton] = ColorFormat.allCases.map { format in
    let button = NSButton(title: format.label, target: nil, action: nil)
    button.setButtonType(.momentaryChange)
    button.bezelStyle = .regularSquare
    button.isBordered = false
    button.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    button.focusRingType = .none
    return button
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: NSView.noIntrinsicMetric, height: 34)
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override var focusRingMaskBounds: NSRect {
    bounds.insetBy(dx: -2, dy: -2)
  }

  private func setup() {
    wantsLayer = true
    layer?.cornerRadius = 10
    layer?.backgroundColor = NSColor(
      srgbRed: 0.93,
      green: 0.95,
      blue: 0.98,
      alpha: 1
    ).cgColor
    layer?.borderWidth = 1
    layer?.borderColor = NSColor(
      srgbRed: 0.83,
      green: 0.88,
      blue: 0.95,
      alpha: 1
    ).cgColor

    hoverView.wantsLayer = true
    hoverView.layer?.cornerRadius = 8
    hoverView.layer?.backgroundColor = NSColor(
      srgbRed: 0.96,
      green: 0.98,
      blue: 1.0,
      alpha: 1
    ).cgColor
    hoverView.alphaValue = 0
    addSubview(hoverView)

    indicatorView.wantsLayer = true
    indicatorView.layer?.cornerRadius = 8
    indicatorView.layer?.backgroundColor = NSColor(
      srgbRed: 0.23,
      green: 0.58,
      blue: 0.98,
      alpha: 0.24
    ).cgColor
    indicatorView.layer?.borderWidth = 1
    indicatorView.layer?.borderColor = NSColor(
      srgbRed: 0.13,
      green: 0.46,
      blue: 0.92,
      alpha: 0.26
    ).cgColor
    indicatorView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.05).cgColor
    indicatorView.layer?.shadowOffset = CGSize(width: 0, height: -1)
    indicatorView.layer?.shadowRadius = 4
    indicatorView.layer?.shadowOpacity = 1
    addSubview(indicatorView)

    for (index, button) in buttons.enumerated() {
      button.tag = index
      button.target = self
      button.action = #selector(handlePress(_:))
      addSubview(button)
    }

    updateButtonStates()
  }

  override func layout() {
    super.layout()

    let count = CGFloat(buttons.count)
    guard count > 0 else { return }

    let segmentWidth = bounds.width / count
    for (index, button) in buttons.enumerated() {
      button.frame = CGRect(
        x: CGFloat(index) * segmentWidth,
        y: 0,
        width: segmentWidth,
        height: bounds.height
      )
    }

    layoutHover(animated: false)
    layoutIndicator(animated: false)
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingAreaRef {
      removeTrackingArea(trackingAreaRef)
    }

    let trackingAreaRef = NSTrackingArea(
      rect: .zero,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingAreaRef)
    self.trackingAreaRef = trackingAreaRef
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    guard showsKeyboardFocusRing, window?.firstResponder === self else {
      return
    }

    NSGraphicsContext.saveGraphicsState()
    NSFocusRingPlacement.only.set()
    NSColor.keyboardFocusIndicatorColor.setFill()
    let ringPath = NSBezierPath(
      roundedRect: bounds.insetBy(dx: 2, dy: 2),
      xRadius: 10,
      yRadius: 10
    )
    ringPath.fill()
    NSGraphicsContext.restoreGraphicsState()
  }

  override func becomeFirstResponder() -> Bool {
    let becameFirstResponder = super.becomeFirstResponder()
    if becameFirstResponder {
      needsDisplay = true
    }
    return becameFirstResponder
  }

  override func resignFirstResponder() -> Bool {
    let resignedFirstResponder = super.resignFirstResponder()
    if resignedFirstResponder {
      showsKeyboardFocusRing = false
      needsDisplay = true
    }
    return resignedFirstResponder
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    updateHover(with: event)
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
    updateHover(with: event)
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    setHoveredIndex(nil, animated: true)
  }

  func setSelectedFormat(_ format: ColorFormat, animated: Bool) {
    selectedFormat = format
    updateButtonStates()
    layoutHover(animated: animated)
    layoutIndicator(animated: animated)
  }

  private func layoutHover(animated: Bool) {
    let targetAlpha: CGFloat
    let targetFrame: CGRect

    if let hoveredIndex, hoveredIndex != selectedFormat.rawValue {
      targetFrame = buttons[hoveredIndex].frame.insetBy(dx: 2, dy: 2)
      targetAlpha = 1
    } else {
      targetFrame = hoverView.frame
      targetAlpha = 0
    }

    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.14
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        if targetAlpha > 0 {
          hoverView.animator().frame = targetFrame
        }
        hoverView.animator().alphaValue = targetAlpha
      }
    } else {
      if targetAlpha > 0 {
        hoverView.frame = targetFrame
      }
      hoverView.alphaValue = targetAlpha
    }
  }

  private func layoutIndicator(animated: Bool) {
    guard !buttons.isEmpty else { return }

    let selectedButton = buttons[selectedFormat.rawValue]
    let targetFrame = selectedButton.frame.insetBy(dx: 2, dy: 2)

    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.18
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        indicatorView.animator().frame = targetFrame
      }
    } else {
      indicatorView.frame = targetFrame
    }
  }

  private func updateButtonStates() {
    for (index, button) in buttons.enumerated() {
      let selected = index == selectedFormat.rawValue
      button.contentTintColor = selected
        ? NSColor(
            srgbRed: 0.05,
            green: 0.27,
            blue: 0.60,
            alpha: 1
          )
        : NSColor(
            srgbRed: 0.31,
            green: 0.40,
            blue: 0.53,
            alpha: 1
          )
    }
  }

  private func updateHover(with event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)
    let hoveredIndex = buttons.firstIndex { $0.frame.contains(location) }
    setHoveredIndex(hoveredIndex, animated: true)
  }

  private func setHoveredIndex(_ index: Int?, animated: Bool) {
    guard hoveredIndex != index else {
      return
    }
    hoveredIndex = index
    layoutHover(animated: animated)
  }

  @objc
  private func handlePress(_ sender: NSButton) {
    guard let format = ColorFormat(rawValue: sender.tag) else {
      return
    }

    showsKeyboardFocusRing = false
    window?.makeFirstResponder(self)
    setHoveredIndex(sender.tag, animated: false)
    needsDisplay = true
    setSelectedFormat(format, animated: true)
    onChange?(format)
  }

  override func keyDown(with event: NSEvent) {
    showsKeyboardFocusRing = true
    needsDisplay = true

    switch event.keyCode {
    case 123:
      moveSelection(delta: -1)
    case 124:
      moveSelection(delta: 1)
    default:
      super.keyDown(with: event)
    }
  }

  private func moveSelection(delta: Int) {
    let allCases = ColorFormat.allCases
    let nextIndex = max(0, min(allCases.count - 1, selectedFormat.rawValue + delta))
    guard let next = ColorFormat(rawValue: nextIndex), next != selectedFormat else {
      return
    }

    setSelectedFormat(next, animated: true)
    onChange?(next)
  }
}

final class ColorSwatchView: NSView {
  var color: NSColor = .clear {
    didSet { needsDisplay = true }
  }

  private let cornerRadius: CGFloat

  init(size: CGSize, cornerRadius: CGFloat) {
    self.cornerRadius = cornerRadius
    super.init(frame: CGRect(origin: .zero, size: size))
    wantsLayer = true
  }

  required init?(coder: NSCoder) {
    self.cornerRadius = 8
    super.init(coder: coder)
    wantsLayer = true
  }

  override var intrinsicContentSize: NSSize {
    frame.size
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    color.setFill()
    path.fill()
    NSColor(calibratedWhite: 0, alpha: 0.08).setStroke()
    path.lineWidth = 1
    path.stroke()
  }
}

final class PaletteSwatchButton: NSButton {
  var color: NSColor = .clear {
    didSet { needsDisplay = true }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    isBordered = false
    setButtonType(.momentaryChange)
    focusRingType = .none
    wantsLayer = true
    layer?.cornerRadius = 11
    layer?.masksToBounds = true
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 32, height: 32)
  }

  override func draw(_ dirtyRect: NSRect) {
    let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
    let path = NSBezierPath(roundedRect: rect, xRadius: 11, yRadius: 11)
    color.setFill()
    path.fill()
    NSColor.black.withAlphaComponent(isHighlighted ? 0.18 : 0.10).setStroke()
    path.lineWidth = 1
    path.stroke()
  }
}

final class HistoryRowView: NSTableCellView {
  private let previewView = NSImageView()
  private let titleField = NSTextField(labelWithString: "")
  private let subtitleField = NSTextField(labelWithString: "")
  private let swatchView = ColorSwatchView(size: CGSize(width: 16, height: 16), cornerRadius: 8)
  private let copyImageView = NSImageView()
  private var trackingAreaRef: NSTrackingArea?
  private var isHovering = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  override func layout() {
    super.layout()
    syncHoverStateWithMouse(animated: false)
  }

  private func setup() {
    focusRingType = .none
    wantsLayer = true
    layer?.cornerRadius = 12
    layer?.backgroundColor = NSColor.white.cgColor
    layer?.borderWidth = 0
    layer?.shadowColor = NSColor.black.withAlphaComponent(0.06).cgColor
    layer?.shadowOffset = CGSize(width: 0, height: -2)
    layer?.shadowRadius = 6
    layer?.shadowOpacity = 0

    let root = NSStackView()
    root.orientation = .horizontal
    root.spacing = 10
    root.alignment = .centerY
    root.translatesAutoresizingMaskIntoConstraints = false
    addSubview(root)

    previewView.translatesAutoresizingMaskIntoConstraints = false
    previewView.imageScaling = .scaleAxesIndependently
    previewView.wantsLayer = true
    previewView.layer?.cornerRadius = 10
    previewView.layer?.masksToBounds = true
    previewView.layer?.borderColor = NSColor(calibratedWhite: 0, alpha: 0.08).cgColor
    previewView.layer?.borderWidth = 1
    NSLayoutConstraint.activate([
      previewView.widthAnchor.constraint(equalToConstant: 46),
      previewView.heightAnchor.constraint(equalToConstant: 46)
    ])

    titleField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
    titleField.lineBreakMode = .byTruncatingMiddle

    subtitleField.font = NSFont.systemFont(ofSize: 11)
    subtitleField.textColor = NSColor.secondaryLabelColor

    let subtitleRow = NSStackView(views: [swatchView, subtitleField])
    subtitleRow.orientation = .horizontal
    subtitleRow.spacing = 6
    subtitleRow.alignment = .centerY

    let textColumn = NSStackView(views: [titleField, subtitleRow])
    textColumn.orientation = .vertical
    textColumn.spacing = 4
    textColumn.alignment = .leading

    let spacer = NSView()
    spacer.translatesAutoresizingMaskIntoConstraints = false
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "doc.on.doc",
        accessibilityDescription: "Copy"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
      copyImageView.image = image?.withSymbolConfiguration(config)
      copyImageView.image?.isTemplate = true
    }
    copyImageView.contentTintColor = NSColor.secondaryLabelColor
    copyImageView.alphaValue = 0
    copyImageView.wantsLayer = true
    copyImageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      copyImageView.widthAnchor.constraint(equalToConstant: 18),
      copyImageView.heightAnchor.constraint(equalToConstant: 18)
    ])

    root.addArrangedSubview(previewView)
    root.addArrangedSubview(textColumn)
    root.addArrangedSubview(spacer)
    root.addArrangedSubview(copyImageView)

    NSLayoutConstraint.activate([
      root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      root.topAnchor.constraint(equalTo: topAnchor, constant: 6),
      root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
    ])
  }

  func configure(item: PickedColor, format: ColorFormat) {
    previewView.image = item.previewImage
    previewView.layer?.backgroundColor = item.rgbColor.cgColor
    swatchView.color = item.rgbColor
    titleField.stringValue = formatColor(item, format: format)
    subtitleField.stringValue = formatColor(item, format: .hex)
    toolTip = "Click to copy \(titleField.stringValue)"
    syncHoverStateWithMouse(animated: false)
  }

  func animateCopyBurst() {
    guard let image = copyImageView.image else {
      return
    }

    let clone = NSImageView(image: image)
    clone.contentTintColor = copyImageView.contentTintColor
    clone.frame = convert(copyImageView.bounds, from: copyImageView)
    clone.alphaValue = 1
    addSubview(clone)

    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.35
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      clone.animator().alphaValue = 0
      var frame = clone.frame
      frame.origin.y += 14
      clone.animator().frame = frame
    } completionHandler: { [weak self] in
      clone.removeFromSuperview()
      self?.copyImageView.alphaValue = self?.isHovering == true ? 1 : 0
    }
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingAreaRef {
      removeTrackingArea(trackingAreaRef)
    }

    let trackingAreaRef = NSTrackingArea(
      rect: .zero,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingAreaRef)
    self.trackingAreaRef = trackingAreaRef
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    setHovering(true, animated: true)
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    setHovering(false, animated: true)
  }

  func syncHoverStateWithMouse(animated: Bool) {
    guard let window else {
      setHovering(false, animated: animated)
      return
    }

    let location = convert(window.mouseLocationOutsideOfEventStream, from: nil)
    setHovering(bounds.contains(location), animated: animated)
  }

  private func setHovering(_ hovering: Bool, animated: Bool) {
    guard isHovering != hovering else {
      return
    }

    isHovering = hovering
    let applyChanges = {
      self.layer?.backgroundColor = (hovering
        ? NSColor(
            srgbRed: 0.92,
            green: 0.96,
            blue: 1.0,
            alpha: 1
          )
        : NSColor.white
      ).cgColor
      self.layer?.shadowOpacity = hovering ? 0.18 : 0
      self.copyImageView.alphaValue = hovering ? 1 : 0
    }

    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.12
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.layer?.backgroundColor = (hovering
          ? NSColor(
              srgbRed: 0.92,
              green: 0.96,
              blue: 1.0,
              alpha: 1
            )
          : NSColor.white
        ).cgColor
        self.layer?.shadowOpacity = hovering ? 0.18 : 0
        self.copyImageView.animator().alphaValue = hovering ? 1 : 0
      }
    } else {
      applyChanges()
    }
  }
}

final class ColorHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  var onRecentPicksChanged: (([RecentPickMenuItem]) -> Void)?

  private var history: [PickedColor] = []
  private var importedPalette: [PickedColor] = []
  private var importedPalettePreviewImage: NSImage?
  private var isImportedPaletteVisible = false
  private var format: ColorFormat = .hex

  private let headerView = HeaderBarView()
  private let titleLabel = NSTextField(labelWithString: "ClrPkr")
  private let pickButton = HeaderPickButton(title: "", target: nil, action: nil)
  private let pinButton = HeaderPickButton(title: "", target: nil, action: nil)
  private let closeButton = TrafficLightButton(title: "", target: nil, action: nil)
  private let formatPicker = FormatPickerView()
  private let dropCaptureView = WholeWindowDropView()
  private let panelView = NativePanelView()
  private let importedPaletteCard = NSView()
  private let importedPaletteThumbnailView = AspectFillImageView()
  private let importedPaletteTitle = NSTextField(labelWithString: "Imported Palette")
  private let importedPaletteSubtitle = NSTextField(labelWithString: "Click a swatch to copy in the selected format")
  private let importedPaletteRemoveButton = NSButton(title: "", target: nil, action: nil)
  private let importedPaletteStrip = NSStackView()
  private let scrollView = NSScrollView()
  private let tableView = NSTableView()
  private let emptyLabel = NSTextField(labelWithString: "Use Pick or drop an image to capture colors.")
  private let countLabel = NSTextField(labelWithString: "0 picks")
  private let clearButton = NSButton(title: "Clear History", target: nil, action: nil)
  private let chromeBackgroundColor = NSColor(
    srgbRed: 0.945,
    green: 0.953,
    blue: 0.965,
    alpha: 1
  )
  private var isShowingDropOverlay = false

  override func loadView() {
    view = NSView()
    dropCaptureView.onDropImage = { [weak self] image in
      self?.handleDroppedImage(image)
    }
    dropCaptureView.onDropStateChanged = { [weak self] isActive in
      self?.updateDropOverlayState(isActive)
    }
    view.wantsLayer = true
    view.layer?.backgroundColor = chromeBackgroundColor.cgColor
    buildInterface()
    refreshInterface()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func addPick(red: Int, green: Int, blue: Int, previewPng: Data?) {
    let color = NSColor(
      srgbRed: CGFloat(red) / 255,
      green: CGFloat(green) / 255,
      blue: CGFloat(blue) / 255,
      alpha: 1
    )
    let item = PickedColor(
      color: color,
      previewImage: previewPng.flatMap(NSImage.init(data:)),
      pickedAt: Date()
    )

    history.insert(item, at: 0)
    refreshInterface()
  }

  func addPalette(colors: [NSColor], previewImage: NSImage?) {
    let items = colors.map {
      PickedColor(
        color: $0,
        previewImage: nil,
        pickedAt: Date()
      )
    }

    importedPalette = items
    importedPalettePreviewImage = previewImage
    isImportedPaletteVisible = true
    history.insert(contentsOf: items, at: 0)
    refreshInterface()
  }

  func currentRecentPickItems() -> [RecentPickMenuItem] {
    Array(history.prefix(10)).map {
      RecentPickMenuItem(
        text: formatColor($0, format: format),
        color: $0.rgbColor
      )
    }
  }

  func setAlwaysOnTop(_ alwaysOnTop: Bool) {
    pinButton.isToggled = alwaysOnTop
    pinButton.toolTip = alwaysOnTop
      ? "Disable always on top"
      : "Keep window always on top"
  }

  private func buildInterface() {
    let root = NSStackView()
    root.orientation = .vertical
    root.spacing = 7
    root.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(root)
    dropCaptureView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(dropCaptureView)

    headerView.translatesAutoresizingMaskIntoConstraints = false
    headerView.wantsLayer = true
    headerView.layer?.backgroundColor = chromeBackgroundColor.cgColor

    titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    titleLabel.alignment = .left
    titleLabel.lineBreakMode = .byTruncatingTail

    closeButton.toolTip = "Close"
    closeButton.target = self
    closeButton.action = #selector(handleCloseWindow(_:))
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      closeButton.image = nil
    } else {
      closeButton.title = ""
    }

    pickButton.toolTip = "Pick color from screen"
    pickButton.target = NSApp.delegate
    pickButton.action = #selector(AppDelegate.startPickerFromToolbar(_:))
    pickButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "eyedropper.full",
        accessibilityDescription: "Pick"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
      pickButton.image = image?.withSymbolConfiguration(config)
      pickButton.image?.isTemplate = true
      pickButton.imagePosition = .imageOnly
    } else {
      pickButton.title = "Pick"
    }

    pinButton.toolTip = "Keep window always on top"
    pinButton.target = NSApp.delegate
    pinButton.action = #selector(AppDelegate.toggleAlwaysOnTopFromToolbar(_:))
    pinButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "pin",
        accessibilityDescription: "Always on top"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
      pinButton.image = image?.withSymbolConfiguration(config)
      pinButton.image?.isTemplate = true
      pinButton.imagePosition = .imageOnly
    } else {
      pinButton.title = "Top"
    }

    let headerSpacer = NSView()
    headerSpacer.translatesAutoresizingMaskIntoConstraints = false
    headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let headerStack = NSStackView(views: [
      closeButton,
      titleLabel,
      headerSpacer,
      pinButton,
      pickButton
    ])
    headerStack.orientation = .horizontal
    headerStack.alignment = .centerY
    headerStack.spacing = 8
    headerStack.translatesAutoresizingMaskIntoConstraints = false
    headerView.addSubview(headerStack)

    NSLayoutConstraint.activate([
      closeButton.widthAnchor.constraint(equalToConstant: 13.5),
      closeButton.heightAnchor.constraint(equalToConstant: 13.5),
      pinButton.widthAnchor.constraint(equalToConstant: 44),
      pinButton.heightAnchor.constraint(equalToConstant: 28),
      pickButton.widthAnchor.constraint(equalToConstant: 44),
      pickButton.heightAnchor.constraint(equalToConstant: 28),
      headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
      headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -2),
      headerStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 2),
      headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -2),
      titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 160),
      titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 10)
    ])

    formatPicker.translatesAutoresizingMaskIntoConstraints = false
    formatPicker.setSelectedFormat(format, animated: false)
    formatPicker.onChange = { [weak self] selected in
      self?.handleFormatChanged(selected)
    }
    NSLayoutConstraint.activate([
      formatPicker.heightAnchor.constraint(equalToConstant: 34)
    ])

    panelView.translatesAutoresizingMaskIntoConstraints = false

    let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("history"))
    tableColumn.resizingMask = .autoresizingMask
    tableView.addTableColumn(tableColumn)
    tableView.headerView = nil
    tableView.backgroundColor = .clear
    tableView.focusRingType = .none
    tableView.selectionHighlightStyle = .none
    tableView.intercellSpacing = NSSize(width: 0, height: 4)
    tableView.rowHeight = 56
    tableView.delegate = self
    tableView.dataSource = self
    tableView.target = self
    tableView.doubleAction = #selector(handleRowActivated(_:))

    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.contentView.postsBoundsChangedNotifications = true
    scrollView.documentView = tableView
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScrollBoundsChanged(_:)),
      name: NSView.boundsDidChangeNotification,
      object: scrollView.contentView
    )

    emptyLabel.alignment = .center
    emptyLabel.textColor = NSColor.secondaryLabelColor
    emptyLabel.font = NSFont.systemFont(ofSize: 13)
    emptyLabel.translatesAutoresizingMaskIntoConstraints = false

    panelView.addSubview(scrollView)
    panelView.addSubview(emptyLabel)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 1),
      scrollView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -1),
      scrollView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 1),
      scrollView.bottomAnchor.constraint(equalTo: panelView.bottomAnchor, constant: -1),
      emptyLabel.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: panelView.centerYAnchor),
      panelView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
    ])

    importedPaletteCard.wantsLayer = true
    importedPaletteCard.layer?.cornerRadius = 12
    importedPaletteCard.layer?.backgroundColor = NSColor.white.cgColor
    importedPaletteCard.layer?.borderWidth = 1
    importedPaletteCard.layer?.borderColor = NSColor(
      srgbRed: 0.84,
      green: 0.89,
      blue: 0.95,
      alpha: 1
    ).cgColor
    importedPaletteCard.translatesAutoresizingMaskIntoConstraints = false

    importedPaletteThumbnailView.translatesAutoresizingMaskIntoConstraints = false

    importedPaletteTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    importedPaletteSubtitle.font = NSFont.systemFont(ofSize: 11)
    importedPaletteSubtitle.textColor = NSColor.secondaryLabelColor
    importedPaletteRemoveButton.bezelStyle = .texturedRounded
    importedPaletteRemoveButton.controlSize = .small
    importedPaletteRemoveButton.target = self
    importedPaletteRemoveButton.action = #selector(handleRemoveImportedPalette(_:))
    importedPaletteRemoveButton.toolTip = "Remove imported palette"
    importedPaletteRemoveButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "xmark",
        accessibilityDescription: "Remove imported palette"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
      importedPaletteRemoveButton.image = image?.withSymbolConfiguration(config)
      importedPaletteRemoveButton.imagePosition = .imageOnly
    } else {
      importedPaletteRemoveButton.title = "x"
    }

    importedPaletteStrip.orientation = .horizontal
    importedPaletteStrip.spacing = 8
    importedPaletteStrip.alignment = .centerY
    importedPaletteStrip.translatesAutoresizingMaskIntoConstraints = false

    let importedPaletteText = NSStackView(views: [importedPaletteTitle, importedPaletteSubtitle])
    importedPaletteText.orientation = .vertical
    importedPaletteText.spacing = 2
    importedPaletteText.alignment = .leading
    importedPaletteText.translatesAutoresizingMaskIntoConstraints = false

    importedPaletteCard.addSubview(importedPaletteThumbnailView)
    importedPaletteCard.addSubview(importedPaletteText)
    importedPaletteCard.addSubview(importedPaletteRemoveButton)
    importedPaletteCard.addSubview(importedPaletteStrip)
    NSLayoutConstraint.activate([
      importedPaletteThumbnailView.leadingAnchor.constraint(equalTo: importedPaletteCard.leadingAnchor, constant: 12),
      importedPaletteThumbnailView.topAnchor.constraint(equalTo: importedPaletteCard.topAnchor, constant: 12),
      importedPaletteThumbnailView.bottomAnchor.constraint(equalTo: importedPaletteCard.bottomAnchor, constant: -12),
      importedPaletteThumbnailView.widthAnchor.constraint(equalTo: importedPaletteThumbnailView.heightAnchor),
      importedPaletteText.leadingAnchor.constraint(equalTo: importedPaletteThumbnailView.trailingAnchor, constant: 10),
      importedPaletteText.trailingAnchor.constraint(lessThanOrEqualTo: importedPaletteRemoveButton.leadingAnchor, constant: -8),
      importedPaletteText.topAnchor.constraint(equalTo: importedPaletteCard.topAnchor, constant: 12),
      importedPaletteRemoveButton.topAnchor.constraint(equalTo: importedPaletteCard.topAnchor, constant: 10),
      importedPaletteRemoveButton.trailingAnchor.constraint(equalTo: importedPaletteCard.trailingAnchor, constant: -10),
      importedPaletteStrip.leadingAnchor.constraint(equalTo: importedPaletteThumbnailView.trailingAnchor, constant: 10),
      importedPaletteStrip.trailingAnchor.constraint(equalTo: importedPaletteCard.trailingAnchor, constant: -12),
      importedPaletteStrip.topAnchor.constraint(equalTo: importedPaletteText.bottomAnchor, constant: 10),
      importedPaletteStrip.bottomAnchor.constraint(equalTo: importedPaletteCard.bottomAnchor, constant: -12)
    ])

    countLabel.font = NSFont.systemFont(ofSize: 11)
    countLabel.textColor = NSColor.secondaryLabelColor

    let countLabelContainer = NSView()
    countLabelContainer.translatesAutoresizingMaskIntoConstraints = false
    countLabel.translatesAutoresizingMaskIntoConstraints = false
    countLabelContainer.addSubview(countLabel)
    NSLayoutConstraint.activate([
      countLabel.leadingAnchor.constraint(equalTo: countLabelContainer.leadingAnchor, constant: 7),
      countLabel.trailingAnchor.constraint(equalTo: countLabelContainer.trailingAnchor),
      countLabel.topAnchor.constraint(equalTo: countLabelContainer.topAnchor),
      countLabel.bottomAnchor.constraint(equalTo: countLabelContainer.bottomAnchor)
    ])

    clearButton.bezelStyle = .rounded
    clearButton.controlSize = .regular
    clearButton.target = self
    clearButton.action = #selector(handleClearHistory(_:))

    let footer = NSStackView(views: [countLabelContainer, NSView(), clearButton])
    footer.orientation = .horizontal
    footer.alignment = .centerY

    root.addArrangedSubview(headerView)
    root.addArrangedSubview(formatPicker)
    root.addArrangedSubview(importedPaletteCard)
    root.addArrangedSubview(panelView)
    root.addArrangedSubview(footer)

    NSLayoutConstraint.activate([
      root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 9),
      root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -9),
      importedPaletteCard.widthAnchor.constraint(equalTo: root.widthAnchor),
      headerView.heightAnchor.constraint(equalToConstant: 30),
      root.topAnchor.constraint(equalTo: view.topAnchor, constant: 9),
      root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -9),
      dropCaptureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      dropCaptureView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      dropCaptureView.topAnchor.constraint(equalTo: view.topAnchor),
      dropCaptureView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func refreshInterface() {
    refreshImportedPaletteSection()
    tableView.reloadData()
    emptyLabel.isHidden = isShowingDropOverlay || !history.isEmpty
    scrollView.isHidden = history.isEmpty
    clearButton.isEnabled = !history.isEmpty
    countLabel.stringValue = history.isEmpty ? "0 picks" : "\(history.count) picks"
    onRecentPicksChanged?(currentRecentPickItems())
  }

  private func updateDropOverlayState(_ isActive: Bool) {
    isShowingDropOverlay = isActive
    panelView.setDropTargetActive(isActive)
    refreshInterface()
  }

  private func handleFormatChanged(_ selected: ColorFormat) {
    format = selected
    refreshInterface()
  }

  @objc
  private func handleClearHistory(_ sender: Any?) {
    history.removeAll()
    importedPalette.removeAll()
    importedPalettePreviewImage = nil
    isImportedPaletteVisible = false
    refreshInterface()
  }

  @objc
  private func handleRemoveImportedPalette(_ sender: Any?) {
    isImportedPaletteVisible = false
    refreshInterface()
  }

  private func handleDroppedImage(_ image: NSImage) {
    let colors = ImagePaletteExtractor.extractPalette(from: image).map(\.color)
    guard !colors.isEmpty else {
      return
    }
    addPalette(colors: colors, previewImage: image)
  }

  func importDroppedImage(_ image: NSImage) {
    handleDroppedImage(image)
  }

  private func refreshImportedPaletteSection() {
    importedPaletteCard.isHidden = importedPalette.isEmpty || !isImportedPaletteVisible
    importedPaletteThumbnailView.image = importedPalettePreviewImage
    importedPaletteSubtitle.stringValue = importedPalette.isEmpty
      ? "Drop an image to build a grouped palette"
      : "Click a swatch to copy as \(format.label)"

    importedPaletteStrip.arrangedSubviews.forEach { view in
      importedPaletteStrip.removeArrangedSubview(view)
      view.removeFromSuperview()
    }

    for item in importedPalette {
      let button = PaletteSwatchButton(frame: .zero)
      button.color = item.rgbColor
      button.target = self
      button.action = #selector(handleImportedPaletteSwatch(_:))
      button.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)
      button.toolTip = "Copy \(formatColor(item, format: format))"
      importedPaletteStrip.addArrangedSubview(button)
    }
  }

  @objc
  private func handleImportedPaletteSwatch(_ sender: NSButton) {
    guard
      let identifier = sender.identifier?.rawValue,
      let item = importedPalette.first(where: { $0.id.uuidString == identifier })
    else {
      return
    }

    copy(item: item)
  }

  @objc
  private func handleRowActivated(_ sender: Any?) {
    copySelectedRow()
  }

  @objc
  private func handleCloseWindow(_ sender: Any?) {
    view.window?.orderOut(sender)
  }

  @objc
  private func handleScrollBoundsChanged(_ notification: Notification) {
    refreshVisibleRowHoverStates()
  }

  private func copySelectedRow() {
    let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
    guard history.indices.contains(row) else {
      return
    }

    if let view = tableView.view(
      atColumn: 0,
      row: row,
      makeIfNecessary: false
    ) as? HistoryRowView {
      view.animateCopyBurst()
    }
    copy(item: history[row])
  }

  private func copy(item: PickedColor) {
    let value = formatColor(item, format: format)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
  }

  private func refreshVisibleRowHoverStates() {
    for row in tableView.rows(in: tableView.visibleRect).location..<(tableView.rows(in: tableView.visibleRect).location + tableView.rows(in: tableView.visibleRect).length) {
      guard row >= 0, row < tableView.numberOfRows else {
        continue
      }
      (tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? HistoryRowView)?
        .syncHoverStateWithMouse(animated: false)
    }
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    history.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let identifier = NSUserInterfaceItemIdentifier("HistoryRowView")
    let item = history[row]
    let view = (tableView.makeView(withIdentifier: identifier, owner: self) as? HistoryRowView)
      ?? {
        let rowView = HistoryRowView()
        rowView.identifier = identifier
        return rowView
      }()
    view.configure(item: item, format: format)
    return view
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    if tableView.selectedRow >= 0 {
      copySelectedRow()
      tableView.deselectAll(nil)
    }
  }
}

func formatColor(_ item: PickedColor, format: ColorFormat) -> String {
  switch format {
  case .hex:
    return String(format: "#%02X%02X%02X", item.red, item.green, item.blue)
  case .rgb:
    return "rgb(\(item.red), \(item.green), \(item.blue))"
  case .hsl:
    return formatHsl(item)
  case .swiftUI:
    return String(
      format: "Color(red: %.3f, green: %.3f, blue: %.3f)",
      Double(item.red) / 255,
      Double(item.green) / 255,
      Double(item.blue) / 255
    )
  }
}

func formatHsl(_ item: PickedColor) -> String {
  let red = Double(item.red) / 255
  let green = Double(item.green) / 255
  let blue = Double(item.blue) / 255
  let maxValue = max(red, max(green, blue))
  let minValue = min(red, min(green, blue))
  let delta = maxValue - minValue

  var hue = 0.0
  let lightness = (maxValue + minValue) / 2
  let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))

  if delta != 0 {
    if maxValue == red {
      hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
    } else if maxValue == green {
      hue = 60 * (((blue - red) / delta) + 2)
    } else {
      hue = 60 * (((red - green) / delta) + 4)
    }
  }

  if hue < 0 {
    hue += 360
  }

  return "hsl(\(Int(round(hue))) \(Int(round(saturation * 100)))% \(Int(round(lightness * 100)))%)"
}

class MainWindow: NSWindow {
  private(set) var historyViewController: ColorHistoryViewController?
  private let chromeBackgroundColor = NSColor(
    srgbRed: 0.945,
    green: 0.953,
    blue: 0.965,
    alpha: 1
  )

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }

  override func awakeFromNib() {
    let historyViewController = ColorHistoryViewController()
    let windowFrame = frame
    contentViewController = historyViewController
    setFrame(windowFrame, display: true)
    self.historyViewController = historyViewController

    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.configureMainWindow(window: self, controller: historyViewController)
    }

    styleMask = [.borderless, .fullSizeContentView]
    title = "ClrPkr"
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    setContentSize(NSSize(width: 360, height: 470))
    minSize = NSSize(width: 330, height: 380)
    center()

    super.awakeFromNib()

    if let frameView = contentView?.superview {
      frameView.wantsLayer = true
      frameView.layer?.cornerRadius = 14
      frameView.layer?.masksToBounds = true
      frameView.layer?.backgroundColor = chromeBackgroundColor.cgColor
    }
  }

}
