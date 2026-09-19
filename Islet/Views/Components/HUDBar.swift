import SwiftUI

/// The level bar used by volume, brightness and keyboard backlight peeks.
struct HUDBar: View {
    var level: Double
    var style: String
    var accent: Color = Color(nsColor: .controlAccentColor)
    var showPercentage = true
    var muted = false

    private var fill: Color {
        switch style {
        case "accent": return accent
        case "decibel": return Color(red: 0.3, green: 0.9, blue: 0.5)
        default: return .white
        }
    }

    private var clamped: Double { muted ? 0 : min(max(level, 0), 1) }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous).fill(.white.opacity(0.2))
                    Capsule(style: .continuous)
                        .fill(fill)
                        .frame(width: clamped > 0 ? max(geo.size.width * clamped, 6) : 0)
                        .shadow(color: style == "glow" ? .white.opacity(0.9) : .clear, radius: 5)
                        .shadow(color: style == "glow" ? .white.opacity(0.5) : .clear, radius: 12)
                }
            }
            .frame(height: 6)
            .animation(.spring(duration: 0.3, bounce: 0.1), value: clamped)
            if showPercentage {
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.numericText())
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }
}
