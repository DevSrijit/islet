import SwiftUI

/// A borderless symbol button with a soft highlight on hover and a squish on press.
struct HoverButton: View {
    let symbol: String
    var size: CGFloat = 14
    var diameter: CGFloat = 28
    var active = false
    var tint: Color = .white
    /// Draws the symbol at reduced opacity, for secondary transport buttons.
    var dim = false
    var help: String? = nil
    let action: () -> Void

    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(active ? tint : .white.opacity(dim ? 0.62 : 1))
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(.white.opacity(hovering ? 0.14 : 0)))
            .scaleEffect(pressed ? 0.86 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { withAnimation(.notchQuick) { pressed = true } } }
                    .onEnded { value in
                        withAnimation(.notchQuick) { pressed = false }
                        if abs(value.translation.width) < 12, abs(value.translation.height) < 12 { action() }
                    }
            )
            .animation(.easeOut(duration: 0.15), value: hovering)
            .help(help ?? "")
    }
}

extension Animation {
    static let notchQuick = Animation.spring(duration: 0.26, bounce: 0.2)
}
