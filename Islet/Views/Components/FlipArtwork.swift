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

    var body: some View {
        ZStack {
            if let shown {
                Image(nsImage: shown).resizable().aspectRatio(contentMode: .fill)
            } else {
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
            withAnimation(.easeIn(duration: 0.16)) { angle = 90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                shown = image
                angle = -90
                withAnimation(.easeOut(duration: 0.2)) { angle = 0 }
            }
        }
    }
}
