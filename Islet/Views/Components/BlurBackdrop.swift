import AppKit
import SwiftUI

/// A progressive blur halo around the open island.
///
/// The window server blurs whatever sits behind the panel. A per-pixel mask makes that blur
/// strongest at the island edge and lets it fade out over `fade` points on an ease-out curve.
/// The curve reaches zero with a flat slope, so the halo has no visible boundary on light or
/// dark backgrounds. The menu bar band at the top stays untouched.
struct BlurBackdrop: NSViewRepresentable {
    /// Distance from the island edge to the point where the halo is gone.
    var fade: CGFloat
    /// Radius of the island's bottom corners. The halo stays concentric with them.
    var cornerRadius: CGFloat
    /// How far the island body sits inside the view on each side, below the top flare.
    var edgeInset: CGFloat
    /// Height of the menu bar band at the top of the view. The halo stays out of it.
    var topInset: CGFloat

    func makeNSView(context: Context) -> MaskedEffectView {
        let view = MaskedEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        view.alphaValue = MaskedEffectView.peakAlpha
        view.geometry = .init(fade: fade, cornerRadius: cornerRadius, edgeInset: edgeInset, topInset: topInset)
        return view
    }

    func updateNSView(_ view: MaskedEffectView, context: Context) {
        view.geometry = .init(fade: fade, cornerRadius: cornerRadius, edgeInset: edgeInset, topInset: topInset)
    }
}

final class MaskedEffectView: NSVisualEffectView {
    struct Geometry: Equatable {
        var fade: CGFloat
        var cornerRadius: CGFloat
        var edgeInset: CGFloat
        var topInset: CGFloat
    }

    /// Opacity of the blur right at the island edge. The mask scales it down from there.
    static let peakAlpha: CGFloat = 0.5
    /// Exponent of the ease-out curve. Higher values pull the halo closer to the island.
    static let falloffPower: Double = 2.2
    /// The halo fades in over this many points below the menu bar band.
    static let topRamp: CGFloat = 24

    var geometry = Geometry(fade: 120, cornerRadius: 22, edgeInset: 8, topInset: 32) {
        didSet { if geometry != oldValue { maskedSize = .zero; needsLayout = true } }
    }
    private var maskedSize: CGSize = .zero
    private var maskedScale: CGFloat = 0

    /// The halo never takes clicks. Pointer events go to the island or through the panel.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? 2
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard bounds.size != maskedSize || scale != maskedScale else { return }
        maskedSize = bounds.size
        maskedScale = scale
        maskImage = Self.cachedMask(size: bounds.size, scale: scale, geometry: geometry)
    }

    private struct MaskKey: Equatable {
        var size: CGSize
        var scale: CGFloat
        var geometry: Geometry
    }
    private static var cache: (key: MaskKey, image: NSImage)?

    /// The view is rebuilt on every open, so the last mask stays cached for reuse.
    static func cachedMask(size: CGSize, scale: CGFloat, geometry: Geometry) -> NSImage? {
        let key = MaskKey(size: size, scale: scale, geometry: geometry)
        if let cache, cache.key == key { return cache.image }
        guard let image = mask(size: size, scale: scale, geometry: geometry) else { return nil }
        cache = (key, image)
        return image
    }

    /// Builds the alpha mask: solid inside the island, easing to transparent outside it.
    ///
    /// The island body is a rounded rectangle that is open at the top. Each pixel stores the
    /// distance from that shape mapped through the ease-out curve, times a short vertical ramp
    /// that keeps the menu bar band clear.
    static func mask(size: CGSize, scale: CGFloat, geometry: Geometry) -> NSImage? {
        let width = Int((size.width * scale).rounded()), height = Int((size.height * scale).rounded())
        guard width > 0, height > 0 else { return nil }

        let fade = max(geometry.fade, 1)
        let radius = max(geometry.cornerRadius, 0)
        let left = geometry.fade + geometry.edgeInset + radius
        let right = size.width - geometry.fade - geometry.edgeInset - radius
        let bottom = size.height - geometry.fade - radius

        // Ease-out lookup so the inner loop stays cheap.
        let steps = 1024
        let curve: [UInt8] = (0..<steps).map { index in
            let t = Double(index) / Double(steps - 1)
            return UInt8((pow(1 - t, falloffPower) * 255).rounded())
        }

        // Horizontal distance to the inner box, per column. It is the same on every row.
        let columnDistance: [CGFloat] = (0..<width).map { px in
            let x = (CGFloat(px) + 0.5) / scale
            return max(left - x, x - right, 0)
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBufferPointer { buffer in
            for py in 0..<height {
                let y = (CGFloat(py) + 0.5) / scale
                let rampT = min(max((y - geometry.topInset) / topRamp, 0), 1)
                let ramp = rampT * rampT * (3 - 2 * rampT)
                if ramp <= 0 { continue }
                let qy = max(y - bottom, 0)
                let qySquared = qy * qy
                let row = py * width * 4
                for px in 0..<width {
                    let qx = columnDistance[px]
                    let distance = (qx * qx + qySquared).squareRoot() - radius
                    let alpha: CGFloat
                    if distance <= 0 {
                        alpha = 1
                    } else if distance >= fade {
                        continue
                    } else {
                        let index = Int(distance / fade * CGFloat(steps - 1))
                        alpha = CGFloat(curve[index]) / 255
                    }
                    let value = UInt8((alpha * ramp * 255).rounded())
                    guard value > 0 else { continue }
                    let offset = row + px * 4
                    // Premultiplied black at this alpha.
                    buffer[offset + 3] = value
                }
            }
        }

        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return NSImage(cgImage: image, size: size)
    }
}
