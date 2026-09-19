import SwiftUI

/// Scrolls text horizontally when it does not fit. Give it `.id(text)` so it restarts on change.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 14, weight: .semibold)
    var color: Color = .white
    var speed: Double = 28
    var gap: CGFloat = 32

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflows: Bool { textWidth > containerWidth + 1 }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: gap) {
                label
                if overflows { label }
            }
            .offset(x: offset)
            .background(
                Text(text).font(font).fixedSize().hidden()
                    .background(GeometryReader { t in Color.clear.preference(key: WidthKey.self, value: t.size.width) })
            )
            .onPreferenceChange(WidthKey.self) { width in
                textWidth = width
                containerWidth = geo.size.width
                restart()
            }
            .onChange(of: geo.size.width) { _, width in containerWidth = width; restart() }
        }
        .frame(height: lineHeight)
        .clipped()
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: overflows ? 8 : 0)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: overflows ? 12 : 0)
            }
        )
    }

    private var label: some View {
        Text(text).font(font).foregroundStyle(color).lineLimit(1).fixedSize()
    }

    private var lineHeight: CGFloat { 20 }

    private func restart() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { offset = 0 }
        guard overflows else { return }
        let distance = textWidth + gap
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.linear(duration: Double(distance) / speed).delay(0).repeatForever(autoreverses: false)) {
                offset = -distance
            }
        }
    }

    private struct WidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
}
