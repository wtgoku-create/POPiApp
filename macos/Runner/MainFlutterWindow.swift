import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var speechInput: SpeechInputBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    speechInput = SpeechInputBridge(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()

    minSize = NSSize(width: 560, height: 540)
    if !setFrameUsingName("POPiMainWindow") {
      setContentSize(NSSize(width: 1180, height: 780))
      center()
    }
    setFrameAutosaveName("POPiMainWindow")
  }
}
