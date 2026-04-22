import Cocoa

enum CopyBurstAnimator {
  static func animate(
    view: NSView,
    in containerView: NSView,
    offsetY: CGFloat = 14,
    duration: TimeInterval = 0.35,
    completion: (() -> Void)? = nil
  ) {
    containerView.addSubview(view)

    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      view.animator().alphaValue = 0
      var frame = view.frame
      frame.origin.y += offsetY
      view.animator().frame = frame
    } completionHandler: {
      view.removeFromSuperview()
      completion?()
    }
  }
}

final class HeaderBarView: NSView {
  override var mouseDownCanMoveWindow: Bool {
    true
  }
}

final class PalettePagerCardView: NSView {
  var onSwipeLeft: (() -> Void)?
  var onSwipeRight: (() -> Void)?
  private var didTriggerTrackpadPage = false

  override func swipe(with event: NSEvent) {
    if event.deltaX > 0 {
      onSwipeLeft?()
    } else if event.deltaX < 0 {
      onSwipeRight?()
    } else {
      super.swipe(with: event)
    }
  }

  override func scrollWheel(with event: NSEvent) {
    let phase = event.phase
    let momentumPhase = event.momentumPhase
    if phase == .began || momentumPhase == .began {
      didTriggerTrackpadPage = false
    }

    let horizontalDelta = event.scrollingDeltaX
    let verticalDelta = event.scrollingDeltaY
    let isMostlyHorizontal = abs(horizontalDelta) > abs(verticalDelta) && abs(horizontalDelta) > 6

    if isMostlyHorizontal && !didTriggerTrackpadPage {
      didTriggerTrackpadPage = true
      if horizontalDelta > 0 {
        onSwipeLeft?()
      } else {
        onSwipeRight?()
      }
      return
    }

    if phase == .ended || phase == .cancelled || momentumPhase == .ended || momentumPhase == .cancelled {
      didTriggerTrackpadPage = false
    }

    super.scrollWheel(with: event)
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
  private enum Animation {
    static let rise: CGFloat = 24
    static let duration: TimeInterval = 0.5
  }

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

  func animateCopyBurst() {
    let clone = NSView(frame: convert(bounds, to: superview))
    clone.wantsLayer = true
    clone.layer?.cornerRadius = 11
    clone.layer?.masksToBounds = true
    clone.layer?.backgroundColor = color.cgColor
    clone.layer?.borderWidth = 1
    clone.layer?.borderColor = NSColor.black.withAlphaComponent(0.10).cgColor

    guard let superview else {
      return
    }

    CopyBurstAnimator.animate(
      view: clone,
      in: superview,
      offsetY: Animation.rise,
      duration: Animation.duration
    )
  }
}
