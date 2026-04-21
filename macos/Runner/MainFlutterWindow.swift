import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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

    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    backgroundColor = NSColor.clear
    styleMask.insert(.fullSizeContentView)
    setContentSize(NSSize(width: 480, height: 720))
    minSize = NSSize(width: 420, height: 560)
    center()

    super.awakeFromNib()
  }
}
