import Cocoa
import FlutterMacOS
import ImageIO

/// User-initiated image reads only. This bridge never observes pasteboard changes.
final class ClipboardImageBridge {
  private static let channelName = "art.popi/clipboard_images"
  private static let byteLimit = 20 * 1024 * 1024
  private static let countLimit = 10
  private static let maxDimension = 8192
  private static let maxPixels = 64 * 1024 * 1024
  private static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
  private static let webp = NSPasteboard.PasteboardType("org.webmproject.webp")

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
    do {
      result(try readImages(from: .general))
    } catch let failure as ClipboardFailure {
      result(FlutterError(code: failure.code, message: failure.message, details: nil))
    } catch {
      result(FlutterError(code: "invalid_content", message: "The pasted image could not be read.", details: nil))
    }
  }

  private func readImages(from pasteboard: NSPasteboard) throws -> [[String: Any]] {
    let items = pasteboard.pasteboardItems ?? []
    var total = 0
    var output: [[String: Any]] = []
    for item in items {
      guard let image = try imageData(from: item) else { continue }
      guard output.count < Self.countLimit else {
        throw ClipboardFailure("too_many_images", "Paste at most \(Self.countLimit) images at once.")
      }
      guard !image.data.isEmpty else {
        throw ClipboardFailure("empty", "The pasted image is empty.")
      }
      guard image.data.count <= Self.byteLimit else {
        throw ClipboardFailure("image_too_large", "A pasted image exceeds 20 MiB.")
      }
      try validateDimensions(image.data)
      total += image.data.count
      guard total <= Self.byteLimit else {
        throw ClipboardFailure("total_too_large", "Pasted images exceed 20 MiB in total.")
      }
      output.append([
        "name": image.name,
        "mimeType": image.mimeType,
        "bytes": FlutterStandardTypedData(bytes: image.data),
      ])
    }
    return output
  }

  private func imageData(from item: NSPasteboardItem) throws -> ClipboardImageData? {
    if let data = item.data(forType: .png) {
      return ClipboardImageData(name: "clipboard-image.png", mimeType: "image/png", data: data)
    }
    if let data = item.data(forType: Self.jpeg) {
      return ClipboardImageData(name: "clipboard-image.jpg", mimeType: "image/jpeg", data: data)
    }
    if let data = item.data(forType: Self.webp) {
      return ClipboardImageData(name: "clipboard-image.webp", mimeType: "image/webp", data: data)
    }
    if let value = item.string(forType: .fileURL),
       let url = URL(string: value), url.isFileURL {
      let resource = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard resource.isRegularFile == true else { return nil }
      guard let size = resource.fileSize else {
        throw ClipboardFailure("invalid_content", "The pasted image size is unavailable.")
      }
      if size > Self.byteLimit {
        throw ClipboardFailure("image_too_large", "A pasted image exceeds 20 MiB.")
      }
      let mimeType: String
      switch url.pathExtension.lowercased() {
      case "png": mimeType = "image/png"
      case "jpg", "jpeg": mimeType = "image/jpeg"
      case "webp": mimeType = "image/webp"
      default: return nil
      }
      return ClipboardImageData(
        name: url.lastPathComponent, mimeType: mimeType,
        data: try Data(contentsOf: url, options: .mappedIfSafe)
      )
    }
    if let tiff = item.data(forType: .tiff) {
      guard tiff.count <= Self.byteLimit else {
        throw ClipboardFailure("image_too_large", "A pasted image exceeds 20 MiB.")
      }
      try validateDimensions(tiff)
      if let bitmap = NSBitmapImageRep(data: tiff),
         let png = bitmap.representation(using: .png, properties: [:]) {
        return ClipboardImageData(name: "clipboard-image.png", mimeType: "image/png", data: png)
      }
    }
    return nil
  }

  private func validateDimensions(_ data: Data) throws {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let values = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = (values[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
          let height = (values[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
          width > 0, height > 0 else {
      throw ClipboardFailure("invalid_content", "The pasted image dimensions are invalid.")
    }
    guard width <= Self.maxDimension, height <= Self.maxDimension,
          width <= Self.maxPixels / height else {
      throw ClipboardFailure("invalid_content", "The pasted image dimensions exceed the safe limit.")
    }
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
