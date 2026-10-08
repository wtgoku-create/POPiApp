import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let unhandled = URLContexts.filter {
      !DouyinLoginBridge.handleURL($0.url, sourceApplication: $0.options.sourceApplication)
    }
    if !unhandled.isEmpty { super.scene(scene, openURLContexts: Set(unhandled)) }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL, DouyinLoginBridge.handleURL(url) { return }
    super.scene(scene, continue: userActivity)
  }
}
