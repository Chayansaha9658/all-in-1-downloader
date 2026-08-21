import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let visible = (self.screen ?? NSScreen.main)?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

    let height = min(860, visible.height * 0.90)
    let width = min(480, visible.width * 0.42)

    self.setContentSize(NSSize(width: width, height: height))
    self.minSize = NSSize(width: 360, height: 540)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}