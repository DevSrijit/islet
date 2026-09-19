import SwiftUI

/// Dancing bars in the style of the Music app. They settle into a row of dots when paused.
struct Visualizer: View {
    var playing: Bool
    var tint: Color
    var style: String
    /// Real audio levels (0...1 per bar). When nil the bars animate on their own.
    var levels: [Float]? = nil
    var barCount = 4
    var height: CGFloat = 16

    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 2.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(fill)
                        .frame(width: barWidth, height: barHeight(index: index, time: t))
                }
            }
            .frame(width: CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing, height: height)
            .opacity(playing ? 1 : 0.6)
            .animation(.spring(duration: 0.4, bounce: 0.2), value: playing)
        }
    }

    private var fill: AnyShapeStyle {
        switch style {
        case "monochrome": return AnyShapeStyle(.white)
        case "gradient": return AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.55), .white.opacity(0.9)], startPoint: .bottom, endPoint: .top))
        default: return AnyShapeStyle(tint)
        }
    }

    private func barHeight(index: Int, time: Double) -> CGFloat {
        guard playing else { return barWidth }
        let minimum = barWidth + 1
        if let levels, index < levels.count {
            let level = min(max(CGFloat(levels[index]), 0), 1)
            return minimum + (height - minimum) * level
        }
        // Two slow sines per bar, offset per index, so the motion looks organic rather than periodic.
        let speeds: [Double] = [5.1, 6.7, 4.3, 7.9, 5.6, 6.2]
        let phases: [Double] = [0, 1.3, 2.1, 0.7, 2.9, 1.9]
        let s = speeds[index % speeds.count], p = phases[index % phases.count]
        let carrier = 0.5 + 0.5 * sin(time * s + p)
        let envelope = 0.55 + 0.45 * sin(time * 1.3 + Double(index) * 0.9)
        let wave = 0.12 + 0.88 * carrier * envelope
        return minimum + (height - minimum) * CGFloat(wave)
    }
}
