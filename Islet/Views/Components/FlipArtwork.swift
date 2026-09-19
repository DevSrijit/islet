import SwiftUI

/// Album artwork that flips like a card when the track changes.
struct FlipArtwork: View {
    var data: Data?
    /// Shown inside the placeholder when there is no artwork, for example a site or app icon.
    var fallback: NSImage? = nil
    var placeholderSymbol = "music.note"
    var cornerRadius: CGFloat
    var flipEnabled = true

    @State private var shown: NSImage?
    @State private var angle: Double = 0
    @State private var lastHash: Int?
    @State private var flipTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let shown {
                Image(nsImage: shown)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .onAppear { shown = data.flatMap(NSImage.init(data:)); lastHash = data?.hashValue }
        .onChange(of: data) { _, new in
            let hash = new?.hashValue
            guard hash != lastHash else { return }
            lastHash = hash
            let image = new.flatMap(NSImage.init(data:))
            guard flipEnabled, shown != nil else { shown = image; return }
            flip(to: image)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: 0.28), Color(white: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                GeometryReader { geo in
                    if let fallback {
                        Image(nsImage: fallback)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.55)
                            .clipShape(RoundedRectangle(cornerRadius: geo.size.width * 0.12, style: .continuous))
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        Image(systemName: placeholderSymbol)
                            .font(.system(size: geo.size.width * 0.38, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
    }

    /// Turns the card edge-on, swaps the image, then turns it back to face the viewer.
    private func flip(to image: NSImage?) {
        flipTask?.cancel()
        withAnimation(.easeIn(duration: 0.16)) { angle = 90 }
        flipTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            shown = image
            angle = -90
            withAnimation(.easeOut(duration: 0.22)) { angle = 0 }
        }
    }
}
