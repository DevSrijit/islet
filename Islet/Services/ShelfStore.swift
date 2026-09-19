import AppKit
import Observation
import QuickLookUI
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var name: String { url.lastPathComponent }
}

/// Files the user parked in the notch. Persists paths across launches.
@MainActor
@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    private let key = "shelfItems"

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        items = paths.map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { ShelfItem(id: UUID(), url: $0) }
    }

    func add(_ urls: [URL]) {
        let existing = Set(items.map(\.url.path))
        let fresh = urls.filter { !existing.contains($0.path) }.map { ShelfItem(id: UUID(), url: $0) }
        guard !fresh.isEmpty else { return }
        items.insert(contentsOf: fresh, at: 0)
        persist()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(items.map(\.url.path), forKey: key)
    }

    // MARK: Actions

    func open(_ item: ShelfItem) { NSWorkspace.shared.open(item.url) }

    func reveal(_ item: ShelfItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }

    func airDrop(_ urls: [URL]) {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: urls)
    }

    func share(_ urls: [URL], from view: NSView, edge: NSRectEdge = .minY) {
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: edge)
    }

    func quickLook(_ item: ShelfItem) {
        QuickLookController.shared.preview(items.map(\.url), startingAt: items.firstIndex(of: item) ?? 0)
    }

    /// Reads file URLs out of dropped item providers.
    static func urls(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let url: URL? = await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        continuation.resume(returning: url)
                    } else if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let url { urls.append(url) }
        }
        return urls
    }
}

/// Drives the system Quick Look panel for shelf items.
@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()
    private var urls: [URL] = []

    func preview(_ urls: [URL], startingAt index: Int) {
        self.urls = urls
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = index
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated { urls[index] as NSURL }
    }
}
