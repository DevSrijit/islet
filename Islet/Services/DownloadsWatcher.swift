import Foundation

/// Fires when a new, complete file appears in ~/Downloads.
///
/// Browsers write into a partial file and rename it into place, but some tools write the final
/// name directly. A file only counts once its size has held still for one second.
final class DownloadsWatcher {
    var onNewFile: ((URL) -> Void)?

    /// How long the size must stay the same before the file counts as complete.
    static let settleInterval: TimeInterval = 1
    /// Give up on a file that keeps growing for this long. A huge download is not a "new file" peek.
    static let maxWait: TimeInterval = 120

    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var pending: Set<String> = []
    private var descriptor: Int32 = -1
    private let partialSuffixes = ["download", "crdownload", "part", "tmp", "partial", "aria2", "!ut"]
    private var started = false

    func start() {
        guard !started, let folder else { return }
        started = true
        known = snapshot()
        descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { [weak self] in self?.scan() }
        source.setCancelHandler { [descriptor] in close(descriptor) }
        source.resume()
        self.source = source
    }

    private func snapshot() -> Set<String> {
        guard let folder,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return Set(names)
    }

    private func scan() {
        guard let folder else { return }
        let now = snapshot()
        let added = now.subtracting(known)
        known = now
        for name in added {
            guard !name.hasPrefix("."),
                  !partialSuffixes.contains((name as NSString).pathExtension.lowercased()),
                  !pending.contains(name) else { continue }
            pending.insert(name)
            let url = folder.appendingPathComponent(name)
            waitUntilSettled(url: url, name: name, lastSize: Self.size(of: url), since: Date())
        }
    }

    /// Reports the file once its size stops changing.
    private func waitUntilSettled(url: URL, name: String, lastSize: Int64?, since: Date) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleInterval) { [weak self] in
            guard let self else { return }
            guard let size = Self.size(of: url) else { self.pending.remove(name); return }
            if let lastSize, lastSize == size {
                self.pending.remove(name)
                self.onNewFile?(url)
            } else if Date().timeIntervalSince(since) > Self.maxWait {
                self.pending.remove(name)
            } else {
                self.waitUntilSettled(url: url, name: name, lastSize: size, since: since)
            }
        }
    }

    private static func size(of url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
