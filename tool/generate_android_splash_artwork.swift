import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// A square canvas prevents Android 12 from stretching the launch artwork.
// The upward offset keeps the full tagline within the 192 dp circular safe area.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("assets/images/startup_artwork.png")
let outputURL = root.appendingPathComponent(
    "android/app/src/main/res/drawable-nodpi/splash_artwork.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let context = CGContext(
        data: nil, width: 1536, height: 1536, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("Cannot load launch artwork") }

context.draw(artwork, in: CGRect(x: 0, y: 271, width: 1536, height: 1077))
guard let result = context.makeImage() else { fatalError("Cannot render artwork") }

// Check the dark tagline pixels against Android's circular safe area.
let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
var taglinePixels = 0
for y in 0..<1536 {
    for x in 0..<1536 {
        let offset = y * context.bytesPerRow + x * 4
        if pixels[offset + 3] > 200 && pixels[offset] < 100
            && pixels[offset + 1] < 100 && pixels[offset + 2] < 100 {
            taglinePixels += 1
            let dx = x - 768
            let dy = y - 768
            precondition(dx * dx + dy * dy < 512 * 512,
                         "Tagline falls outside Android's safe area")
        }
    }
}
precondition(taglinePixels > 1000, "Tagline is missing from launch artwork")
print("Verified \(taglinePixels) tagline pixels inside Android's safe area")
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("Cannot create PNG") }
CGImageDestinationAddImage(destination, result, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write PNG") }

if CommandLine.arguments.count > 1 {
    let preview = CGContext(
        data: nil, width: 288, height: 288, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    preview.setFillColor(CGColor(gray: 1, alpha: 1))
    preview.fill(CGRect(x: 0, y: 0, width: 288, height: 288))
    preview.addEllipse(in: CGRect(x: 48, y: 48, width: 192, height: 192))
    preview.clip()
    preview.draw(result, in: CGRect(x: 0, y: 0, width: 288, height: 288))
    let previewURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let destination = CGImageDestinationCreateWithURL(
        previewURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, preview.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
}
