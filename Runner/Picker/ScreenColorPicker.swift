import Cocoa

struct PickedColorPayload {
  let red: Int
  let green: Int
  let blue: Int
  let hex: String
  let previewPng: Data
}

final class ScreenColorPicker {
  private let hideWindow: () -> Void
  private let showWindow: () -> Void
  private let onPick: (PickedColorPayload) -> Void
  private var overlayPanels: [PickerOverlayPanel] = []
  private var lensPanel: PickerLensPanel?
  private var lensView: PickerLensView?

  init(
    hideWindow: @escaping () -> Void,
    showWindow: @escaping () -> Void,
    onPick: @escaping (PickedColorPayload) -> Void
  ) {
    self.hideWindow = hideWindow
    self.showWindow = showWindow
    self.onPick = onPick
  }

  func start() {
    guard overlayPanels.isEmpty, lensPanel == nil else {
      return
    }

    hideWindow()

    for screen in NSScreen.screens {
      let panel = PickerOverlayPanel(
        contentRect: screen.frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      let view = PickerOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
      view.bridge = self
      view.screenFrame = screen.frame

      panel.contentView = view
      configurePickerPanel(panel)
      overlayPanels.append(panel)
    }

    let lensSize = CGSize(width: 184, height: 216)
    let lensPanel = PickerLensPanel(
      contentRect: CGRect(origin: .zero, size: lensSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    let lensView = PickerLensView(frame: CGRect(origin: .zero, size: lensSize))
    lensView.bridge = self
    lensPanel.contentView = lensView
    configureLensPanel(lensPanel)
    lensPanel.ignoresMouseEvents = true

    self.lensPanel = lensPanel
    self.lensView = lensView

    NSApp.activate(ignoringOtherApps: true)
    NSCursor.crosshair.push()

    overlayPanels.forEach { panel in
      panel.orderFrontRegardless()
      panel.makeKey()
    }
    lensPanel.orderFrontRegardless()
    refresh(at: NSEvent.mouseLocation)
  }

  fileprivate func complete(with sample: PixelSample) {
    tearDownOverlay()
    showWindow()
    onPick(
      PickedColorPayload(
        red: sample.red,
        green: sample.green,
        blue: sample.blue,
        hex: sample.hex,
        previewPng: sample.previewPng
      )
    )
  }

  func cancel() {
    tearDownOverlay()
    showWindow()
  }

  fileprivate func refresh(at mousePoint: CGPoint) {
    guard let sample = PixelSampler.sample(at: mousePoint) else {
      return
    }

    lensView?.sample = sample
    lensView?.mousePoint = mousePoint
    lensView?.needsDisplay = true

    guard let lensPanel else {
      return
    }

    let lensFrame = PickerLensView.frameForLens(
      around: mousePoint,
      visibleFrame: sample.screenFrame
    )
    lensPanel.setFrame(lensFrame, display: true)
    lensPanel.orderFrontRegardless()
  }

  private func tearDownOverlay() {
    overlayPanels.forEach { $0.orderOut(nil) }
    overlayPanels.removeAll()
    lensPanel?.orderOut(nil)
    lensPanel = nil
    lensView = nil
    NSCursor.pop()
  }

  private func configurePickerPanel(_ panel: NSPanel) {
    panel.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.001)
    panel.level = NSWindow.Level(
      rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow))
    )
    panel.isOpaque = false
    panel.hasShadow = false
    panel.sharingType = .none
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .ignoresCycle
    ]
    panel.acceptsMouseMovedEvents = true
  }

  private func configureLensPanel(_ panel: NSPanel) {
    configurePickerPanel(panel)
    panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
    panel.hasShadow = true
    panel.backgroundColor = .clear
  }
}

final class PickerOverlayPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

final class PickerLensPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class PickerOverlayView: NSView {
  weak var bridge: ScreenColorPicker?
  var screenFrame: CGRect = .zero

  override var acceptsFirstResponder: Bool { true }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.makeFirstResponder(self)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    return self
  }

  override func mouseMoved(with event: NSEvent) {
    bridge?.refresh(at: NSEvent.mouseLocation)
  }

  override func mouseDragged(with event: NSEvent) {
    bridge?.refresh(at: NSEvent.mouseLocation)
  }

  override func mouseDown(with event: NSEvent) {
    if let sample = PixelSampler.sample(at: NSEvent.mouseLocation) {
      bridge?.complete(with: sample)
    }
  }

  override func rightMouseDown(with event: NSEvent) {
    bridge?.cancel()
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      bridge?.cancel()
      return
    }

    super.keyDown(with: event)
  }
}

final class PickerLensView: NSView {
  weak var bridge: ScreenColorPicker?
  fileprivate var sample: PixelSample?
  var mousePoint: CGPoint = .zero

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
  }

  static func frameForLens(around point: CGPoint, visibleFrame: CGRect) -> CGRect {
    let size = CGSize(width: 184, height: 216)
    var origin = CGPoint(x: point.x + 26, y: point.y - size.height - 18)

    if origin.x + size.width > visibleFrame.maxX - 18 {
      origin.x = point.x - size.width - 26
    }
    if origin.y < visibleFrame.minY + 18 {
      origin.y = point.y + 18
    }
    if origin.y + size.height > visibleFrame.maxY - 18 {
      origin.y = visibleFrame.maxY - size.height - 18
    }
    if origin.x < visibleFrame.minX + 18 {
      origin.x = visibleFrame.minX + 18
    }

    return CGRect(origin: origin, size: size)
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.setFill()
    dirtyRect.fill()

    guard let sample, let context = NSGraphicsContext.current?.cgContext else {
      return
    }

    let lensRect = bounds

    let bubbleRadius: CGFloat = 20
    let bubblePath = NSBezierPath(
      roundedRect: lensRect,
      xRadius: bubbleRadius,
      yRadius: bubbleRadius
    )
    NSColor(calibratedWhite: 0.10, alpha: 0.96).setFill()
    bubblePath.fill()
    NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
    bubblePath.lineWidth = 1
    bubblePath.stroke()

    let previewInset: CGFloat = 12
    let previewHeight = lensRect.height - 48
    let previewRect = CGRect(
      x: lensRect.minX + previewInset,
      y: lensRect.minY + 36,
      width: lensRect.width - previewInset * 2,
      height: previewHeight
    )

    context.saveGState()
    let previewRadius = max(12, bubbleRadius - previewInset)
    let previewPath = NSBezierPath(
      roundedRect: previewRect,
      xRadius: previewRadius,
      yRadius: previewRadius
    )
    previewPath.addClip()
    context.interpolationQuality = .none
    context.draw(sample.previewImage, in: previewRect)
    drawGrid(in: previewRect, context: context)
    drawCenterMark(in: previewRect, context: context)
    context.restoreGState()

    let swatchRect = CGRect(x: 12, y: 10, width: 18, height: 18)
    NSColor(
      calibratedRed: CGFloat(sample.red) / 255,
      green: CGFloat(sample.green) / 255,
      blue: CGFloat(sample.blue) / 255,
      alpha: 1
    ).setFill()
    NSBezierPath(roundedRect: swatchRect, xRadius: 6, yRadius: 6).fill()

    let label = sample.hex
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
      .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 1)
    ]
    label.draw(
      at: CGPoint(x: swatchRect.maxX + 8, y: 12),
      withAttributes: attributes
    )
  }

  private func drawGrid(in rect: CGRect, context: CGContext) {
    context.saveGState()
    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.10).cgColor)
    context.setLineWidth(1)

    let cellSize = rect.width / 15
    for index in 1..<15 {
      let offset = rect.minX + CGFloat(index) * cellSize
      context.move(to: CGPoint(x: offset, y: rect.minY))
      context.addLine(to: CGPoint(x: offset, y: rect.maxY))
    }
    for index in 1..<15 {
      let offset = rect.minY + CGFloat(index) * cellSize
      context.move(to: CGPoint(x: rect.minX, y: offset))
      context.addLine(to: CGPoint(x: rect.maxX, y: offset))
    }

    context.strokePath()
    context.restoreGState()
  }

  private func drawCenterMark(in rect: CGRect, context: CGContext) {
    let cellSize = rect.width / 15
    let centerRect = CGRect(
      x: rect.midX - cellSize / 2,
      y: rect.midY - cellSize / 2,
      width: cellSize,
      height: cellSize
    )

    context.saveGState()
    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.75).cgColor)
    context.setLineWidth(2)
    context.stroke(centerRect)
    context.restoreGState()
  }
}

private struct PixelSample {
  let red: Int
  let green: Int
  let blue: Int
  let hex: String
  let previewImage: CGImage
  let previewPng: Data
  let screenFrame: CGRect
}

private enum PixelSampler {
  static func sample(at point: CGPoint) -> PixelSample? {
    guard
      let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
      let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else {
      return nil
    }

    let displayId = CGDirectDisplayID(displayNumber.uint32Value)
    let displayBounds = CGDisplayBounds(displayId)
    let widthRatio = displayBounds.width / screen.frame.width
    let heightRatio = displayBounds.height / screen.frame.height
    let localX = (point.x - screen.frame.minX) * widthRatio
    let localY = (point.y - screen.frame.minY) * heightRatio
    let pixelHeight = displayBounds.height
    let pixelWidth = displayBounds.width
    let pixelX = floor(localX)
    let pixelY = floor(pixelHeight - localY - 1)

    guard
      let pixelImage = CGDisplayCreateImage(
        displayId,
        rect: CGRect(x: pixelX, y: pixelY, width: 1, height: 1)
      ),
      let previewImage = previewImage(
        displayId: displayId,
        pixelX: pixelX,
        pixelY: pixelY,
        maxWidth: pixelWidth,
        maxHeight: pixelHeight
      ),
      let previewPng = pngData(for: previewImage)
    else {
      return nil
    }

    let bitmap = NSBitmapImageRep(cgImage: pixelImage)
    guard let color = bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB) else {
      return nil
    }

    let red = Int(round(color.redComponent * 255))
    let green = Int(round(color.greenComponent * 255))
    let blue = Int(round(color.blueComponent * 255))
    let hex = String(format: "#%02X%02X%02X", red, green, blue)

    return PixelSample(
      red: red,
      green: green,
      blue: blue,
      hex: hex,
      previewImage: previewImage,
      previewPng: previewPng,
      screenFrame: screen.visibleFrame
    )
  }

  private static func previewImage(
    displayId: CGDirectDisplayID,
    pixelX: CGFloat,
    pixelY: CGFloat,
    maxWidth: CGFloat,
    maxHeight: CGFloat
  ) -> CGImage? {
    let previewSize: CGFloat = 15
    let half = floor(previewSize / 2)
    let originX = max(0, min(pixelX - half, maxWidth - previewSize))
    let originY = max(0, min(pixelY - half, maxHeight - previewSize))

    return CGDisplayCreateImage(
      displayId,
      rect: CGRect(x: originX, y: originY, width: previewSize, height: previewSize)
    )
  }

  private static func pngData(for image: CGImage) -> Data? {
    let bitmap = NSBitmapImageRep(cgImage: image)
    return bitmap.representation(using: .png, properties: [:])
  }
}
