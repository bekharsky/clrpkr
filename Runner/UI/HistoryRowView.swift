import Cocoa

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
    subtitleField.stringValue = historySubtitle(for: item)
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
    CopyBurstAnimator.animate(view: clone, in: self) { [weak self] in
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
