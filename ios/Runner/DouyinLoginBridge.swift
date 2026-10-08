import Flutter
import UIKit

#if targetEnvironment(simulator)
/// The vendor SDK has no arm64 simulator slice; preserve the channel contract.
final class DouyinLoginBridge {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorize":
      result(["status": "unavailable", "reason": "simulator_unsupported"])
    case "cancelAuthorization":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func handleURL(_ url: URL, sourceApplication: String? = nil) -> Bool {
    return false
  }
}
#else
import DouyinOpenSDK

/// Keeps SDK authorization and callbacks out of Flutter's presentation layer.
final class DouyinLoginBridge {
  private var pendingResult: FlutterResult?
  private var pendingState: String?
  private var authRequest: DouyinOpenSDKAuthRequest?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: String] ?? [:]
    switch call.method {
    case "authorize":
      authorize(arguments, result: result)
    case "cancelAuthorization":
      if let state = arguments["state"], state == pendingState {
        finish(["status": "canceled"])
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func handleURL(_ url: URL, sourceApplication: String? = nil) -> Bool {
    let configuredKey = Bundle.main.object(forInfoDictionaryKey: "DouyinClientKey") as? String
    let configuredLink = Bundle.main.object(forInfoDictionaryKey: "douyin_universalLink") as? String
    let isSchemeCallback = url.scheme == configuredKey
    let isLinkCallback = configuredLink.map { url.absoluteString.hasPrefix($0) } ?? false
    guard isSchemeCallback || isLinkCallback else { return false }
    return DouyinOpenSDKApplicationDelegate.sharedInstance().application(
      UIApplication.shared, open: url, sourceApplication: sourceApplication, annotation: nil
    )
  }

  private func authorize(_ arguments: [String: String], result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(["status": "failed", "reason": "authorization_in_progress"])
      return
    }
    guard let clientKey = arguments["clientKey"], !clientKey.isEmpty,
          clientKey == Bundle.main.object(forInfoDictionaryKey: "DouyinClientKey") as? String,
          let universalLink = arguments["universalLink"],
          universalLink == Bundle.main.object(forInfoDictionaryKey: "douyin_universalLink") as? String,
          let state = arguments["state"], !state.isEmpty else {
      result(["status": "failed", "reason": "native_configuration_mismatch"])
      return
    }
    let sdk = DouyinOpenSDKApplicationDelegate.sharedInstance()
    guard sdk.registerAppId(clientKey) else {
      result(["status": "failed", "reason": "sdk_registration_failed"])
      return
    }
    guard sdk.isAppInstalled() else {
      result(["status": "unavailable", "reason": "douyin_not_installed"])
      return
    }
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    guard var viewController = window?.rootViewController else {
      result(["status": "failed", "reason": "no_presenting_view_controller"])
      return
    }
    while let presented = viewController.presentedViewController {
      viewController = presented
    }

    pendingResult = result
    pendingState = state
    let request = DouyinOpenSDKAuthRequest()
    request.permissions = NSOrderedSet(array: ["user_info"])
    request.state = state
    authRequest = request
    let started = request.send(viewController) { [weak self] response in
      DispatchQueue.main.async {
        guard let self = self, self.pendingState == state else { return }
        guard let response = response else {
          self.finish(["status": "failed", "reason": "empty_sdk_response"])
          return
        }
        if response.errCode.rawValue == -2 {
          self.finish(["status": "canceled"])
        } else if response.isSucceed, response.state == state,
                  let code = response.code, !code.isEmpty {
          self.finish(["status": "authorized", "code": code, "state": state])
        } else {
          self.finish([
            "status": "failed", "reason": "sdk_authorization_failed",
            "errorCode": String(response.errCode.rawValue),
            "stateMatches": String(response.state == state)
          ])
        }
      }
    }
    if !started { finish(["status": "failed", "reason": "sdk_launch_failed"]) }
  }

  private func finish(_ response: [String: String]) {
    let result = pendingResult
    pendingResult = nil
    pendingState = nil
    authRequest = nil
    result?(response)
  }
}
#endif
