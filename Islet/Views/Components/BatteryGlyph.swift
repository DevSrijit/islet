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

    var body: some View {
        let height = width * 0.46
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.28, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
                RoundedRectangle(cornerRadius: height * 0.2, style: .continuous)
                    .fill(color)
                    .padding(2)
                    .frame(width: max((width - 4) * CGFloat(percent) / 100 + 4, 6))
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.7, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                        .frame(width: width, height: height)
                }
            }
            .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.45))
                .frame(width: 1.5, height: height * 0.4)
        }
        .animation(.easeOut(duration: 0.3), value: percent)
    }
}
