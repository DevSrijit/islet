import SwiftUI
import UniformTypeIdentifiers

/// Expanded notch, Shelf tab: park files here, drag them back out, AirDrop or Quick Look them.
struct ShelfView: View {
    var model: NotchViewModel
    @State private var targeted = false

    private var shelf: ShelfStore { model.shelf }

    var body: some View {
        ZStack {
            if shelf.items.isEmpty {
                empty
            } else {
                items
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(targeted ? 0.12 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(.white.opacity(targeted ? 0.6 : 0.2))
                )
        )
        .animation(.easeOut(duration: 0.18), value: targeted)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            Task {
                let urls = await ShelfStore.urls(from: providers)
                guard !urls.isEmpty else { return }
                shelf.add(urls)
                Haptics.play(.levelChange)
                SoundPlayer.play(.drop)
            }
            return true
        }
        .onChange(of: targeted) { _, new in model.isDropTargeted = new }
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .symbolEffect(.bounce, value: targeted)
            Text("Drop files here")
                .font(.system(size: 13, weight: .semibold))
            Text("Drag them out anywhere, AirDrop them, or Quick Look from the menu.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
    }

    private var items: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(shelf.items) { item in
                        ShelfItemView(item: item, shelf: shelf)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
            HStack(spacing: 6) {
                Text("\(shelf.items.count) item\(shelf.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                ShelfAction(symbol: "airplane.departure", title: "AirDrop") { shelf.airDrop(shelf.items.map(\.url)) }
                ShelfAction(symbol: "trash", title: "Clear") { withAnimation(.notchQuick) { shelf.clear() } }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

private struct ShelfAction: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(hovering ? 0.22 : 0.12)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
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
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 68)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(hovering ? 0.12 : 0)))
        .scaleEffect(hovering ? 1.04 : 1)
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
        .transition(.scale.combined(with: .opacity))
    }
}
