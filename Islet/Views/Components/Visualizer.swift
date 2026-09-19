import SwiftUI

/// Four dancing bars. Flat when paused.
struct Visualizer: View {
    var playing: Bool
    var tint: Color
    var style: String
    /// Real audio levels (0...1 per bar). When nil the bars animate on their own.
    var levels: [Float]? = nil
    var barCount = 4
    var height: CGFloat = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(fill)
                        .frame(width: 3, height: barHeight(index: index, time: t))
                }
            }
            .frame(height: height)
            .animation(.easeOut(duration: 0.25), value: playing)
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
        guard playing else { return 3 }
        if let levels, index < levels.count {
            return 3 + (height - 3) * CGFloat(levels[index])
        }
        let speeds: [Double] = [5.1, 6.7, 4.3, 7.9, 5.6, 6.2]
        let phases: [Double] = [0, 1.3, 2.1, 0.7, 2.9, 1.9]
        let s = speeds[index % speeds.count], p = phases[index % phases.count]
        let wave = 0.5 + 0.5 * sin(time * s + p) * (0.7 + 0.3 * sin(time * 1.3 + Double(index)))
        return 3 + (height - 3) * CGFloat(wave)
    }
}
