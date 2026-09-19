import AppKit
import SwiftUI

/// The progressive blur under the open island: the screen content directly below the island
/// blurs and darkens most at the island's bottom edge and fades to nothing further down.
/// Real behind-window blur on the window server, masked with a vertical falloff.
struct BlurBackdrop: NSViewRepresentable {
    /// Points over which the side edges soften.
    var sideFade: CGFloat = 22
    /// Exponent of the vertical falloff. Higher keeps the blur closer to the island.
    var power: CGFloat = 1.7

    func makeNSView(context: Context) -> MaskedEffectView {
        let view = MaskedEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        view.alphaValue = 0.92
        view.sideFade = sideFade
        view.power = power
        return view
    }

    func updateNSView(_ view: MaskedEffectView, context: Context) {
        view.sideFade = sideFade
        view.power = power
    }
}

final class MaskedEffectView: NSVisualEffectView {
    var sideFade: CGFloat = 22 { didSet { maskedSize = .zero; needsLayout = true } }
    var power: CGFloat = 1.7 { didSet { maskedSize = .zero; needsLayout = true } }
    private var maskedSize: CGSize = .zero

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        guard bounds.size != maskedSize, bounds.width > 0, bounds.height > 0 else { return }
        maskedSize = bounds.size
        maskImage = Self.mask(size: bounds.size, sideFade: sideFade, power: power)
    }

    /// Opaque along the top edge, easing to clear at the bottom, with soft sides.
    static func mask(size: CGSize, sideFade: CGFloat, power: CGFloat) -> NSImage {
        NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let space = CGColorSpaceCreateDeviceRGB()
            // Vertical falloff sampled at many stops so the curve stays smooth.
            let steps = 24
            var colors: [CGColor] = []
            var locations: [CGFloat] = []
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                colors.append(NSColor.black.withAlphaComponent(pow(1 - t, power)).cgColor)
                locations.append(t)
            }
            let vertical = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
            ctx.drawLinearGradient(vertical, start: CGPoint(x: 0, y: rect.minY), end: CGPoint(x: 0, y: rect.maxY), options: [])
            // Multiply in soft side edges.
            let edge = min(sideFade / rect.width, 0.45)
            let clear = NSColor.black.withAlphaComponent(0).cgColor, black = NSColor.black.cgColor
            let horizontal = CGGradient(colorsSpace: space, colors: [clear, black, black, clear] as CFArray, locations: [0, edge, 1 - edge, 1])!
            ctx.setBlendMode(.destinationIn)
            ctx.drawLinearGradient(horizontal, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
            return true
        }
    }
}
