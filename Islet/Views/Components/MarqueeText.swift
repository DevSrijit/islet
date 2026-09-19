import SwiftUI

/// Scrolls text horizontally when it does not fit.
///
/// A timeline drives the offset from a start date, so the motion never fights an implicit
/// animation and never jitters. A text change resets the start date, which restarts the cycle
/// from the hold at the leading edge.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 14, weight: .semibold)
    var color: Color = .white
    /// Points per second.
    var speed: Double = 28
    var gap: CGFloat = 32

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var cycleStart = Date()

    /// Seconds the text rests at the leading edge before each pass.
    private let hold: Double = 1.6
    private let lineHeight: CGFloat = 20
    private var overflows: Bool { textWidth > containerWidth + 1 }

    var body: some View {
        GeometryReader { geo in
            Group {
                if overflows {
                    TimelineView(.animation) { context in
                        HStack(spacing: gap) {
                            label
                            label
                        }
                        .offset(x: offset(at: context.date))
                    }
                } else {
                    label
                }
            }
            .frame(width: geo.size.width, height: lineHeight, alignment: .leading)
            .onChange(of: geo.size.width, initial: true) { _, width in
                if width != containerWidth { containerWidth = width }
            }
        }
        .frame(height: lineHeight)
        .background(measurer)
        .clipped()
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: overflows ? 10 : 0)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: overflows ? 14 : 0)
            }
        )
        .onChange(of: text) { _, _ in cycleStart = .now }
        .onChange(of: overflows) { _, _ in cycleStart = .now }
    }

    private var label: some View {
        Text(text).font(font).foregroundStyle(color).lineLimit(1).fixedSize()
    }

    /// A hidden copy of the text reports its natural width.
    private var measurer: some View {
        Text(text).font(font).lineLimit(1).fixedSize().hidden()
            .background(GeometryReader { t in Color.clear.preference(key: WidthKey.self, value: t.size.width) })
            .onPreferenceChange(WidthKey.self) { width in
                if width != textWidth { textWidth = width }
            }
    }

    private func offset(at date: Date) -> CGFloat {
        let distance = textWidth + gap
        guard distance > 0, speed > 0 else { return 0 }
        let travel = Double(distance) / speed
        let cycle = hold + travel
        let elapsed = date.timeIntervalSince(cycleStart)
        let phase = elapsed.truncatingRemainder(dividingBy: cycle)
        guard phase > hold else { return 0 }
        return -CGFloat((phase - hold) * speed)
    }

    private struct WidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
}
