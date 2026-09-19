import SwiftUI

/// Playback timeline with drag-to-seek. Times sit outside the bar in monospaced digits.
///
/// After a seek the bar keeps the dragged position until the player reports a position near
/// the target, so it never snaps back to the old position first.
struct Scrubber: View {
    var position: TimeInterval
    var duration: TimeInterval
    var tint: Color
    var onScrubbing: (Bool) -> Void
    var onSeek: (TimeInterval) -> Void

    @State private var dragProgress: Double?
    @State private var pendingSeek: TimeInterval?
    @State private var hovering = false

    private var hasDuration: Bool { duration.isFinite && duration > 0 }
    private var active: Bool { hovering || dragProgress != nil }

    private var progress: Double {
        if let dragProgress { return dragProgress }
        guard hasDuration, position.isFinite else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(hasDuration ? Self.format(progress * duration) : "0:00")
                .frame(width: 32, alignment: .leading)
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(width * progress, 4))
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                        .offset(x: min(max(width * progress - 5, 0), width - 10))
                        .scaleEffect(active ? 1 : 0.4)
                        .opacity(active ? 1 : 0)
                }
                .frame(height: active ? 6 : 4)
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard hasDuration else { return }
                            if dragProgress == nil { onScrubbing(true) }
                            dragProgress = min(max(value.location.x / width, 0), 1)
                        }
                        .onEnded { value in
                            guard hasDuration else { return }
                            let target = min(max(value.location.x / width, 0), 1) * duration
                            pendingSeek = target
                            onSeek(target)
                            onScrubbing(false)
                            Task { @MainActor in
                                // Release even if the player never reports the new position.
                                try? await Task.sleep(for: .seconds(2.5))
                                if pendingSeek == target { release() }
                            }
                        }
                )
                .onHover { hovering = $0 }
                .animation(.spring(duration: 0.28, bounce: 0.15), value: active)
            }
            .frame(height: 14)
            Text(hasDuration ? "-" + Self.format(max(duration - progress * duration, 0)) : "0:00")
                .frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(.white.opacity(0.55))
        .contentTransition(.numericText())
        .onChange(of: position) { _, new in
            guard let pendingSeek, abs(new - pendingSeek) < 2 else { return }
            release()
        }
    }

    private func release() {
        pendingSeek = nil
        withAnimation(.easeOut(duration: 0.2)) { dragProgress = nil }
    }

    static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
