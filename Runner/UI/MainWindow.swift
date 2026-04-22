import Cocoa

final class MainWindow: NSWindow {
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

    configureWindow()
    super.awakeFromNib()
    styleWindowFrame()
  }

  private func configureWindow() {
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
  }

  private func styleWindowFrame() {
    if let frameView = contentView?.superview {
      frameView.wantsLayer = true
      frameView.layer?.cornerRadius = 14
      frameView.layer?.masksToBounds = true
      frameView.layer?.backgroundColor = chromeBackgroundColor.cgColor
    }
  }
}
