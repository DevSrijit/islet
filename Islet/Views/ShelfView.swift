import SwiftUI
import UniformTypeIdentifiers

/// Expanded notch, Shelf tab: park files here, drag them back out, AirDrop or Quick Look them.
struct ShelfView: View {
    var model: NotchViewModel
    @State private var targeted = false

    private var shelf: ShelfStore { model.shelf }

    var body: some View {
        VStack(spacing: 6) {
            header
            ZStack {
                if shelf.items.isEmpty {
                    empty
                } else {
                    items
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: NotchRootView.openBottomRadius - NotchRootView.contentMargin, style: .continuous)
                    .fill(.white.opacity(targeted ? 0.14 : 0.06))
            )
        }
        .animation(.easeOut(duration: 0.18), value: targeted)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            Task {
                let urls = await ShelfStore.urls(from: providers)
                guard !urls.isEmpty else { return }
                withAnimation(.notchQuick) { shelf.add(urls) }
                Haptics.play(.levelChange)
                SoundPlayer.play(.drop)
            }
            return true
        }
        .onChange(of: targeted) { _, new in model.isDropTargeted = new }
    }

    /// Way back to Home on the left, the item count in the middle, actions on the right.
    private var header: some View {
        HStack(spacing: 0) {
            ShelfHeaderButton(symbol: "chevron.left", title: "Home", help: "Back to Home") {
                withAnimation(model.spring) { model.tab = .home }
            }
            Spacer(minLength: 0)
            Text(countLabel)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .contentTransition(.numericText())
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                HoverButton(symbol: "square.and.arrow.up", size: 11.5, diameter: 24, dim: true, help: "AirDrop all") {
                    shelf.airDrop(shelf.items.map(\.url))
                }
                HoverButton(symbol: "trash", size: 11.5, diameter: 24, dim: true, help: "Clear the shelf") {
                    withAnimation(.notchQuick) { shelf.clear() }
                }
            }
            .opacity(shelf.items.isEmpty ? 0 : 1)
            .allowsHitTesting(!shelf.items.isEmpty)
        }
        .frame(height: 24)
        .animation(.notchQuick, value: shelf.items.count)
    }

    private var countLabel: String {
        switch shelf.items.count {
        case 0: return "Shelf"
        case 1: return "1 item"
        default: return "\(shelf.items.count) items"
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .symbolEffect(.bounce, value: targeted)
            Text("Drop files here")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var items: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(shelf.items) { item in
                    ShelfItemView(item: item, shelf: shelf)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
        }
    }
}

/// Chevron plus a word, for the way back to Home.
private struct ShelfHeaderButton: View {
    let symbol: String
    let title: String
    var help: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(hovering ? 1 : 0.7))
            .padding(.leading, 6)
            .padding(.trailing, 9)
            .frame(height: 24)
            .background(Capsule().fill(.white.opacity(hovering ? 0.14 : 0)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(help ?? title)
    }
}

struct ShelfItemView: View {
    let item: ShelfItem
    var shelf: ShelfStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 66)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(hovering ? 0.1 : 0)))
        .scaleEffect(hovering ? 1.04 : 1)
        .offset(y: hovering ? -1 : 0)
        .onHover { hovering = $0 }
        .animation(.notchQuick, value: hovering)
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .onTapGesture(count: 2) { shelf.open(item) }
        .contextMenu {
            Button("Open") { shelf.open(item) }
            Button("Quick Look") { shelf.quickLook(item) }
            Button("Reveal in Finder") { shelf.reveal(item) }
            Button("AirDrop") { shelf.airDrop([item.url]) }
            Divider()
            Button("Remove from Shelf") { withAnimation(.notchQuick) { shelf.remove(item) } }
        }
        .help(item.url.path)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
