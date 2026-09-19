import SwiftUI

/// A battery outline filled to the current level, tinted by state.
struct BatteryGlyph: View {
    var percent: Int
    var charging: Bool
    var low: Bool
    var width: CGFloat = 24

    private var color: Color {
        if charging { return Color(red: 0.2, green: 0.85, blue: 0.4) }
        if low { return Color(red: 1, green: 0.32, blue: 0.3) }
        return .white
    }

    private var level: CGFloat { CGFloat(min(max(percent, 0), 100)) / 100 }

    var body: some View {
        let height = width * 0.46
        let outerRadius = height * 0.3
        let inset: CGFloat = 2
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 1)
                RoundedRectangle(cornerRadius: max(outerRadius - inset, 1), style: .continuous)
                    .fill(color)
                    .frame(width: max((width - 2 * inset) * level, height - 2 * inset))
                    .padding(inset)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.72, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: width, height: height)
                }
            }
            .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.5))
                .frame(width: 1.5, height: height * 0.4)
        }
        .animation(.spring(duration: 0.4, bounce: 0.1), value: percent)
        .animation(.easeOut(duration: 0.25), value: charging)
    }
}
