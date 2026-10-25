import Flutter
import UIKit
import Darwin
import Metal
import QuartzCore
import os.log

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let douyinLogin = DouyinLoginBridge()
  private var speechInput: SpeechInputBridge?
  private let launchDiagnostics = LaunchDiagnostics()
  private var inspectedRenderLayer = false
  private var renderLayerObserver: NSObjectProtocol?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    launchDiagnostics.start()
    // UIScene apps do not receive the legacy applicationDidBecomeActive callback.
    renderLayerObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification, object: nil, queue: .main
    ) { [weak self] notification in
      guard let scene = notification.object as? UIWindowScene,
            scene.session.role == .windowApplication,
            application.connectedScenes.contains(scene) else { return }
      self?.inspectRenderLayer(application)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(15)) { [weak self] in
      self?.inspectedRenderLayer = true
      self?.stopObservingRenderLayer()
    }
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    launchDiagnostics.mark("native_launch_ready")
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    launchDiagnostics.mark("engine_initialize")
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LaunchDiagnostics") {
      let channel = FlutterMethodChannel(
        name: "art.popi/launch_diagnostics", binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "mark" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let stage = call.arguments as? String,
              LaunchDiagnostics.dartStages.contains(stage) else {
          result(FlutterError(code: "invalid_stage", message: "Unknown launch stage.", details: nil))
          return
        }
        self?.launchDiagnostics.mark(stage)
        result(nil)
      }
    }
    launchDiagnostics.mark("plugins_register_begin")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    launchDiagnostics.mark("plugins_register_end")
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DouyinLoginBridge") {
      let channel = FlutterMethodChannel(
        name: "art.popi/douyin_login", binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.douyinLogin.handle(call, result: result)
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpeechInputBridge") {
      speechInput = SpeechInputBridge(messenger: registrar.messenger())
    }
    launchDiagnostics.mark("engine_ready")
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    inspectRenderLayer(application)
  }

  private func inspectRenderLayer(_ application: UIApplication) {
    guard !inspectedRenderLayer else { return }
    inspectedRenderLayer = true
    stopObservingRenderLayer()
    let flutterController = (window?.rootViewController as? FlutterViewController) ??
      application.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap { $0.windows }
        .compactMap { $0.rootViewController as? FlutterViewController }
        .first
    let layer = flutterController?.viewIfLoaded?.layer
    let stage: String
    if let layer, let flutterLayer = NSClassFromString("FlutterMetalLayer"), layer.isKind(of: flutterLayer) {
      stage = "render_layer_flutter"
    } else if layer is CAMetalLayer {
      stage = "render_layer_system"
    } else {
      stage = "render_layer_unknown"
    }
    launchDiagnostics.mark(stage)
  }

  private func stopObservingRenderLayer() {
    if let observer = renderLayerObserver { NotificationCenter.default.removeObserver(observer) }
    renderLayerObserver = nil
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

/// Short-lived, content-free memory samples for diagnosing native launch exits.
private final class LaunchDiagnostics {
  static let dartStages: Set<String> = [
    "dart_binding_ready", "preferences_ready", "frosted_ready", "run_app",
    "first_frame", "access_restore", "access_login", "access_authenticated",
    "repository_restore", "repository_ready",
    "home_init", "home_build", "home_first_frame", "refresh_begin", "refresh_end",
  ]

  private let queue = DispatchQueue(label: "art.popi.launch_diagnostics", qos: .utility)
  private let log = OSLog(subsystem: "art.popi.launch_diagnostics", category: "memory")
  private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
  private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
  private var startedAt: DispatchTime?
  private var timer: DispatchSourceTimer?
  private var ticks = 0
  private var reportedStages = Set<String>()
  private var metalDevice: MTLDevice?

  func start() {
    queue.async { [self] in
      guard startedAt == nil else { return }
      startedAt = .now()
      emit("native_launch", memory: Self.memory())
      let source = DispatchSource.makeTimerSource(queue: queue)
      timer = source
      source.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
      source.setEventHandler { [weak self] in
        guard let self, let startedAt = self.startedAt else { return }
        let memory = Self.memory()
        if DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds >= 15_000_000_000 {
          self.timer?.cancel()
          self.timer = nil
          self.emit("sampling_complete", memory: memory)
          return
        }
        self.ticks += 1
        if self.ticks.isMultiple(of: 2) { self.emit("sample", memory: memory) }
      }
      source.resume()
    }
  }

  func mark(_ stage: String) {
    queue.async { [self] in
      guard let startedAt,
            DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds < 15_000_000_000,
            reportedStages.insert(stage).inserted else { return }
      // Do not initialize a GPU device while measuring the pre-engine baseline.
      if stage == "engine_ready" { metalDevice = MTLCreateSystemDefaultDevice() }
      emit(stage, memory: Self.memory())
    }
  }

  private func emit(_ stage: String, memory: (Double, Double, Double)?) {
    var malloc = malloc_statistics_t()
    malloc_zone_statistics(nil, &malloc)
    let mib = 1_048_576.0
    let inUse = Double(malloc.size_in_use) / mib
    let allocated = Double(malloc.size_allocated) / mib
    // -1 means unavailable/not yet queried. These overlapping counters are not additive.
    let metal = metalDevice.map { Double($0.currentAllocatedSize) / mib } ?? -1
    if let memory {
      os_log(
        "POPiLaunch stage=%{public}@ version=%{public}@ build=%{public}@ phys_footprint_mib=%{public}.1f resident_mib=%{public}.1f virtual_mib=%{public}.1f malloc_inuse_mib=%{public}.1f malloc_allocated_mib=%{public}.1f metal_allocated_mib=%{public}.1f",
        log: log, type: .default, stage, version, build, memory.0, memory.1, memory.2, inUse, allocated, metal
      )
    } else {
      os_log(
        "POPiLaunch stage=%{public}@ version=%{public}@ build=%{public}@ phys_footprint_mib=unavailable resident_mib=unavailable virtual_mib=unavailable malloc_inuse_mib=%{public}.1f malloc_allocated_mib=%{public}.1f metal_allocated_mib=%{public}.1f",
        log: log, type: .default, stage, version, build, inUse, allocated, metal
      )
    }
  }

  private static func memory() -> (Double, Double, Double)? {
    var info = task_vm_info_data_t()
    let capacity = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    var count = mach_msg_type_number_t(capacity)
    let status = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    // Older kernels may return only a prefix of the SDK's current struct.
    guard status == KERN_SUCCESS,
          let offset = MemoryLayout<task_vm_info_data_t>.offset(of: \.phys_footprint),
          Int(count) * MemoryLayout<integer_t>.size >= offset + MemoryLayout<mach_vm_size_t>.size else {
      return nil
    }
    let mib = 1_048_576.0
    return (Double(info.phys_footprint) / mib, Double(info.resident_size) / mib, Double(info.virtual_size) / mib)
  }
}
