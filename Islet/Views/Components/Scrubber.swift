import SwiftUI

/// Playback timeline with drag-to-seek.
struct Scrubber: View {
    var position: TimeInterval
    var duration: TimeInterval
    var tint: Color
    var onScrubbing: (Bool) -> Void
    var onSeek: (TimeInterval) -> Void

    @State private var dragProgress: Double?
    @State private var hovering = false

    private var progress: Double {
        if let dragProgress { return dragProgress }
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(duration > 0 ? Self.format(progress * duration) : "-:--")
                .frame(width: 30, alignment: .leading)
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule().fill(tint).frame(width: max(width * progress, 4)).opacity(duration > 0 ? 1 : 0)
                    Circle()
                        .fill(.white)
                        .frame(width: 9, height: 9)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .offset(x: max(width * progress - 4.5, 0))
                        .opacity(hovering || dragProgress != nil ? 1 : 0)
                }
                .frame(height: hovering || dragProgress != nil ? 7 : 5)
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragProgress == nil { onScrubbing(true) }
                            dragProgress = min(max(value.location.x / width, 0), 1)
                        }
                        .onEnded { value in
                            let p = min(max(value.location.x / width, 0), 1)
                            onSeek(p * duration)
                            // Keep the dragged value until the player reports the new position.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dragProgress = nil }
                            onScrubbing(false)
                        }
                )
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.15), value: hovering)
            }
            .frame(height: 12)
            Text(duration > 0 ? "-" + Self.format(max(duration - progress * duration, 0)) : "--:--")
                .frame(width: 34, alignment: .trailing)
        }
        .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(.white.opacity(0.5))
        .contentTransition(.numericText())
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
