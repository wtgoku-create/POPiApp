import AVFoundation
import Flutter
import Speech
import UIKit

/// Owns one guarded Apple Speech session and exposes it over Flutter's method channel.
final class SpeechInputBridge: NSObject {
  private final class Session {
    let id: String
    let locale: String
    var startResult: FlutterResult?
    var didStart = false
    var isStopping = false
    var hasText = false
    var finishTimeout: DispatchWorkItem?

    init(id: String, locale: String, startResult: @escaping FlutterResult) {
      self.id = id
      self.locale = locale
      self.startResult = startResult
    }
  }

  private struct AudioSessionConfiguration {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
  }

  private let channel: FlutterMethodChannel
  private var session: Session?
  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var audioEngine: AVAudioEngine?
  private var tapInstalled = false
  private var requestEnded = false
  private var audioSessionActive = false
  private var previousAudioSessionConfiguration: AudioSessionConfiguration?
  private var notificationTokens: [NSObjectProtocol] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "art.popi/speech_input", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.onMain { self?.handle(call, result: result) }
    }
    notificationTokens.append(
      NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.handleLifecycleInterruption()
      }
    )
    notificationTokens.append(
      NotificationCenter.default.addObserver(
        forName: UIApplication.willTerminateNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.handleLifecycleInterruption()
      }
    )
  }

  deinit {
    notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    channel.setMethodCallHandler(nil)
    cleanResources(cancelTask: true)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      guard
        let arguments = call.arguments as? [String: Any],
        let sessionId = arguments["sessionId"] as? String,
        !sessionId.isEmpty,
        let locale = arguments["locale"] as? String,
        !locale.isEmpty
      else {
        result(flutterError("unavailable", "Missing speech session or locale."))
        return
      }
      start(sessionId: sessionId, locale: locale, result: result)
    case "stop":
      stop(sessionId: sessionId(from: call.arguments))
      result(nil)
    case "cancel":
      cancel(sessionId: sessionId(from: call.arguments))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(sessionId: String, locale: String, result: @escaping FlutterResult) {
    if let current = session {
      if current.didStart {
        failRuntime(
          current,
          code: "cancelled",
          message: "Replaced by a new speech session."
        )
      } else {
        failSetup(
          current,
          code: "cancelled",
          message: "Replaced by a new speech session."
        )
      }
    }

    let next = Session(id: sessionId, locale: locale, startResult: result)
    session = next
    requestSpeechPermission(for: next)
  }

  private func requestSpeechPermission(for target: Session) {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      continueAfterSpeechAuthorization(for: target)
    case .notDetermined:
      SFSpeechRecognizer.requestAuthorization { [weak self, weak target] status in
        self?.onMain {
          guard let self, let target, self.session === target else { return }
          if status == .authorized {
            self.continueAfterSpeechAuthorization(for: target)
          } else {
            self.failSetup(target, code: "permission_denied", message: "Speech recognition permission was denied.")
          }
        }
      }
    case .denied, .restricted:
      failSetup(target, code: "permission_denied", message: "Speech recognition permission was denied.")
    @unknown default:
      failSetup(target, code: "unavailable", message: "Speech recognition authorization is unavailable.")
    }
  }

  private func continueAfterSpeechAuthorization(for target: Session) {
    guard session === target else { return }
    guard let speechRecognizer = SFSpeechRecognizer(
      locale: Locale(identifier: target.locale)
    ) else {
      failSetup(target, code: "unavailable", message: "The requested speech locale is unavailable.")
      return
    }
    guard speechRecognizer.isAvailable else {
      failSetup(target, code: "unavailable", message: "Speech recognition is currently unavailable.")
      return
    }
    recognizer = speechRecognizer
    requestMicrophonePermission(for: target)
  }

  private func requestMicrophonePermission(for target: Session) {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      beginRecognition(for: target)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { [weak self, weak target] granted in
        self?.onMain {
          guard let self, let target, self.session === target else { return }
          if granted {
            self.beginRecognition(for: target)
          } else {
            self.failSetup(target, code: "permission_denied", message: "Microphone permission was denied.")
          }
        }
      }
    case .denied, .restricted:
      failSetup(target, code: "permission_denied", message: "Microphone permission was denied.")
    @unknown default:
      failSetup(target, code: "unavailable", message: "Microphone authorization is unavailable.")
    }
  }

  private func beginRecognition(for target: Session) {
    guard session === target, let recognizer else { return }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation

    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      failSetup(target, code: "audio", message: "No valid microphone input format is available.")
      return
    }

    do {
      let audioSession = AVAudioSession.sharedInstance()
      previousAudioSessionConfiguration = AudioSessionConfiguration(
        category: audioSession.category,
        mode: audioSession.mode,
        options: audioSession.categoryOptions
      )
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      audioSessionActive = true

      recognitionRequest = request
      requestEnded = false
      audioEngine = engine
      input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
        request?.append(buffer)
      }
      tapInstalled = true

      recognitionTask = recognizer.recognitionTask(with: request) { [weak self, weak target] result, error in
        DispatchQueue.main.async {
          guard let self, let target else { return }
          self.handleRecognition(result, error: error, for: target)
        }
      }

      engine.prepare()
      try engine.start()
      target.didStart = true
      let startResult = target.startResult
      target.startResult = nil
      startResult?(nil)
    } catch {
      failSetup(target, code: "audio", message: error.localizedDescription)
    }
  }

  private func stop(sessionId: String?) {
    guard let target = session, target.id == sessionId else { return }
    guard target.didStart else {
      finish(
        target,
        emitDone: true,
        pendingStartError: flutterError("cancelled", "Speech input stopped before recording began."),
        cancelTask: true
      )
      return
    }
    guard !target.isStopping else { return }

    target.isStopping = true
    stopAudioCapture()
    guard session === target else { return }
    recognitionTask?.finish()
    guard session === target else { return }

    let timeout = DispatchWorkItem { [weak self, weak target] in
      guard let self, let target, self.session === target else { return }
      self.finish(target, emitDone: true, pendingStartError: nil, cancelTask: true)
    }
    target.finishTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: timeout)
  }

  private func cancel(sessionId: String?) {
    guard let target = session, target.id == sessionId else { return }
    finish(
      target,
      emitDone: false,
      pendingStartError: flutterError("cancelled", "Speech input was cancelled."),
      cancelTask: true
    )
  }

  private func handleRecognition(
    _ recognitionResult: SFSpeechRecognitionResult?,
    error: Error?,
    for target: Session
  ) {
    guard session === target, target.didStart else { return }

    if let recognitionResult {
      let text = recognitionResult.bestTranscription.formattedString
      if !text.isEmpty {
        target.hasText = true
        emit([
          "sessionId": target.id,
          "type": "result",
          "text": text,
          "isFinal": recognitionResult.isFinal,
        ])
      }
      if recognitionResult.isFinal {
        if text.isEmpty && !target.hasText {
          failRuntime(target, code: "no_speech", message: "No speech was detected.")
        } else {
          finish(target, emitDone: true, pendingStartError: nil, cancelTask: true)
        }
        return
      }
    }

    if let error {
      let code = runtimeErrorCode(error, hasText: target.hasText)
      failRuntime(target, code: code, message: error.localizedDescription)
    }
  }

  private func failSetup(_ target: Session, code: String, message: String) {
    guard session === target else { return }
    finish(
      target,
      emitDone: false,
      pendingStartError: flutterError(code, message),
      cancelTask: true
    )
  }

  private func failRuntime(_ target: Session, code: String, message: String) {
    guard session === target else { return }
    emit(["sessionId": target.id, "type": "error", "code": code, "text": message])
    finish(target, emitDone: true, pendingStartError: nil, cancelTask: true)
  }

  private func finish(
    _ target: Session,
    emitDone: Bool,
    pendingStartError: FlutterError?,
    cancelTask: Bool
  ) {
    guard session === target else { return }
    target.finishTimeout?.cancel()
    target.finishTimeout = nil
    let startResult = target.startResult
    target.startResult = nil
    session = nil
    cleanResources(cancelTask: cancelTask)
    if let startResult {
      startResult(pendingStartError ?? flutterError("cancelled", "Speech input ended before recording began."))
    }
    if emitDone {
      emit(["sessionId": target.id, "type": "done"])
    }
  }

  private func stopAudioCapture() {
    if let engine = audioEngine {
      if engine.isRunning { engine.stop() }
      if tapInstalled {
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
      }
      engine.reset()
      audioEngine = nil
    }
    if !requestEnded {
      recognitionRequest?.endAudio()
      requestEnded = true
    }
    restoreAudioSession()
  }

  private func cleanResources(cancelTask: Bool) {
    stopAudioCapture()
    if cancelTask {
      recognitionTask?.cancel()
    }
    recognitionTask = nil
    recognitionRequest = nil
    requestEnded = false
    recognizer = nil
  }

  private func restoreAudioSession() {
    let audioSession = AVAudioSession.sharedInstance()
    if audioSessionActive {
      audioSessionActive = false
      try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    guard let previous = previousAudioSessionConfiguration else { return }
    previousAudioSessionConfiguration = nil
    try? audioSession.setCategory(
      previous.category,
      mode: previous.mode,
      options: previous.options
    )
  }

  private func handleLifecycleInterruption() {
    guard let target = session else { return }
    if target.didStart {
      failRuntime(target, code: "cancelled", message: "Speech input was interrupted.")
    } else {
      failSetup(target, code: "cancelled", message: "Speech input was interrupted.")
    }
  }

  private func runtimeErrorCode(_ error: Error, hasText: Bool) -> String {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain || nsError.domain == kCFErrorDomainCFNetwork as String {
      return "network"
    }
    if nsError.domain == AVFoundationErrorDomain || nsError.domain == NSOSStatusErrorDomain {
      return "audio"
    }
    if #available(iOS 17.0, *), nsError.domain == SFSpeechErrorDomain, nsError.code == 2 {
      return "audio"
    }
    if nsError.domain == NSCocoaErrorDomain, nsError.code == NSUserCancelledError {
      return "cancelled"
    }
    return hasText ? "recognition_failed" : "no_speech"
  }

  private func emit(_ arguments: [String: Any]) {
    channel.invokeMethod("event", arguments: arguments)
  }

  private func sessionId(from arguments: Any?) -> String? {
    (arguments as? [String: Any])?["sessionId"] as? String
  }

  private func flutterError(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }

  private func onMain(_ action: @escaping () -> Void) {
    if Thread.isMainThread {
      action()
    } else {
      DispatchQueue.main.async(execute: action)
    }
  }
}
