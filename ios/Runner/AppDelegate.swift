import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let douyinLogin = DouyinLoginBridge()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DouyinLoginBridge") {
      let channel = FlutterMethodChannel(
        name: "art.popi/douyin_login", binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.douyinLogin.handle(call, result: result)
      }
    }
  }

  override func application(
    _ app: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if DouyinLoginBridge.handleURL(
      url, sourceApplication: options[.sourceApplication] as? String
    ) { return true }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication, continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if let url = userActivity.webpageURL, DouyinLoginBridge.handleURL(url) { return true }
    return super.application(
      application, continue: userActivity, restorationHandler: restorationHandler
    )
  }
}
