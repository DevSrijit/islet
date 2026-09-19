import AppKit
import CoreImage
import SwiftUI

extension NSImage {
    /// A saturated, bright version of the image's average colour, suitable for use on black.
    func dominantTint() -> Color? {
        guard let tiff = tiffRepresentation, let ciImage = CIImage(data: tiff) else { return nil }
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: CIVector(cgRect: extent)])
        guard let output = filter?.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let color = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        // Album art averages tend to be muddy. Push toward a vivid, readable accent.
        let saturation = s < 0.15 ? s : max(s, 0.6)
        let brightness = max(b, 0.82)
        return Color(NSColor(hue: h, saturation: saturation, brightness: brightness, alpha: 1))
    }

    /// Icon for the app that owns a media session.
    static func appIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func appName(bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
