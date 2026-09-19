import AppKit
import SwiftUI

/// A progressive blur halo: blurs the screen around the island, strongest at the island's edge
/// and fading to nothing over `fade` points. Real behind-window blur, done by the window server.
struct BlurBackdrop: NSViewRepresentable {
    var fade: CGFloat = 40
    var cornerRadius: CGFloat = 24

    func makeNSView(context: Context) -> MaskedEffectView {
        let view = MaskedEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = 0.4
        view.fade = fade
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ view: MaskedEffectView, context: Context) {
        view.fade = fade
        view.cornerRadius = cornerRadius
    }
}

final class MaskedEffectView: NSVisualEffectView {
    var fade: CGFloat = 40 { didSet { maskedSize = .zero; needsLayout = true } }
    var cornerRadius: CGFloat = 24 { didSet { maskedSize = .zero; needsLayout = true } }
    private var maskedSize: CGSize = .zero

    override func layout() {
        super.layout()
        guard bounds.size != maskedSize, bounds.width > 0, bounds.height > 0 else { return }
        maskedSize = bounds.size
        maskImage = Self.mask(size: bounds.size, fade: fade, cornerRadius: cornerRadius)
    }

    /// Solid inside the island, easing to transparent over `fade` points outside it.
    static func mask(size: CGSize, fade: CGFloat, cornerRadius: CGFloat) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setBlendMode(.copy)
            let steps = 32
            for step in 0..<steps {
                let t = CGFloat(step) / CGFloat(steps - 1)          // 0 at the outer edge, 1 at the island
                let inset = (1 - t) * fade
                let eased = t * t * (3 - 2 * t)
                // The island touches the top of the screen, so no fade above it.
                let inner = CGRect(x: rect.minX + inset, y: rect.minY + inset, width: rect.width - 2 * inset, height: rect.height - inset)
                guard inner.width > 0, inner.height > 0 else { continue }
                let radius = min(cornerRadius + inset, inner.width / 2, inner.height / 2)
                ctx.setFillColor(NSColor.black.withAlphaComponent(eased).cgColor)
                ctx.addPath(CGPath(roundedRect: inner, cornerWidth: radius, cornerHeight: radius, transform: nil))
                ctx.fillPath()
            }
            return true
        }
    }
}
