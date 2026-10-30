import Flutter
import ImageIO
import UIKit

/// User-initiated image reads only. This bridge never observes pasteboard changes.
final class ClipboardImageBridge {
  private static let channelName = "art.popi/clipboard_images"
  private static let byteLimit = 20 * 1024 * 1024
  private static let countLimit = 10
  private static let maxDimension = 8192
  private static let maxPixels = 64 * 1024 * 1024
  private static let preferredTypes = ["public.png", "public.jpeg", "org.webmproject.webp"]

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "readImages" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let pasteboard = UIPasteboard.general
    guard pasteboard.hasImages else {
      result([])
      return
    }
    let providers = pasteboard.itemProviders.filter { provider in
      Self.preferredTypes.contains { provider.hasItemConformingToTypeIdentifier($0) } ||
        provider.hasItemConformingToTypeIdentifier("public.image")
    }
    guard providers.count <= Self.countLimit else {
      result(error("too_many_images", "Paste at most \(Self.countLimit) images at once."))
      return
    }
    guard !providers.isEmpty else {
      result([])
      return
    }

    let group = DispatchGroup()
    let state = ClipboardLoadState(count: providers.count)
    for (index, provider) in providers.enumerated() {
      let identifier = Self.preferredTypes.first {
        provider.hasItemConformingToTypeIdentifier($0)
      } ?? "public.image"
      group.enter()
      provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, loadError in
        defer { group.leave() }
        do {
          if let loadError { throw loadError }
          guard let data else {
            throw ClipboardFailure("invalid_content", "The pasted image could not be read.")
          }
          state.store(try Self.validatedImage(data: data, index: index), at: index)
        } catch let failure as ClipboardFailure {
          state.fail(failure)
        } catch {
          state.fail(ClipboardFailure("invalid_content", "The pasted image could not be read."))
        }
      }
    }
    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      let snapshot = state.snapshot()
      if let failure = snapshot.failure {
        result(error(failure.code, failure.message))
        return
      }
      let resolved = snapshot.images.compactMap { $0 }
      guard resolved.count == providers.count else {
        result(error("invalid_content", "The pasted image could not be read."))
        return
      }
      let total = resolved.reduce(0) { $0 + $1.data.count }
      guard total <= Self.byteLimit else {
        result(error("total_too_large", "Pasted images exceed 20 MiB in total."))
        return
      }
      result(resolved.map { image in
        [
          "name": image.name,
          "mimeType": image.mimeType,
          "bytes": FlutterStandardTypedData(bytes: image.data),
        ]
      })
    }
  }

  private static func validatedImage(data: Data, index: Int) throws -> ClipboardImageData {
    guard !data.isEmpty else {
      throw ClipboardFailure("empty", "The pasted image is empty.")
    }
    guard data.count <= byteLimit else {
      throw ClipboardFailure("image_too_large", "A pasted image exceeds 20 MiB.")
    }
    guard let mimeType = detectedMimeType(data) else {
      throw ClipboardFailure("unsupported_type", "Only PNG, JPEG, and WebP images can be pasted.")
    }
    try validateDimensions(data)
    let suffix = mimeType == "image/jpeg" ? "jpg" : mimeType.split(separator: "/").last.map(String.init) ?? "png"
    return ClipboardImageData(
      name: "clipboard-image-\(index + 1).\(suffix)", mimeType: mimeType, data: data
    )
  }

  private static func validateDimensions(_ data: Data) throws {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let values = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = (values[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
          let height = (values[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
          width > 0, height > 0 else {
      throw ClipboardFailure("invalid_content", "The pasted image dimensions are invalid.")
    }
    guard width <= maxDimension, height <= maxDimension,
          width <= maxPixels / height else {
      throw ClipboardFailure("invalid_content", "The pasted image dimensions exceed the safe limit.")
    }
  }

  private static func detectedMimeType(_ data: Data) -> String? {
    let bytes = [UInt8](data.prefix(12))
    if bytes.count >= 8 && bytes[0..<8].elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
      return "image/png"
    }
    if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
      return "image/jpeg"
    }
    if bytes.count >= 12,
       String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF",
       String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" {
      return "image/webp"
    }
    return nil
  }

  private func error(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }
}

private struct ClipboardImageData {
  let name: String
  let mimeType: String
  let data: Data
}

private struct ClipboardFailure: Error {
  init(_ code: String, _ message: String) {
    self.code = code
    self.message = message
  }

  let code: String
  let message: String
}

private final class ClipboardLoadState: @unchecked Sendable {
  init(count: Int) {
    images = Array(repeating: nil, count: count)
  }

  private let lock = NSLock()
  private var images: [ClipboardImageData?]
  private var failure: ClipboardFailure?

  func store(_ image: ClipboardImageData, at index: Int) {
    lock.lock()
    images[index] = image
    lock.unlock()
  }

  func fail(_ value: ClipboardFailure) {
    lock.lock()
    if failure == nil { failure = value }
    lock.unlock()
  }

  func snapshot() -> (images: [ClipboardImageData?], failure: ClipboardFailure?) {
    lock.lock()
    defer { lock.unlock() }
    return (images, failure)
  }
}
