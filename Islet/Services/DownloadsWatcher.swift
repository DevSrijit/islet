import Foundation

/// Fires when a new, complete file appears in ~/Downloads.
final class DownloadsWatcher {
    var onNewFile: ((URL) -> Void)?

    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var descriptor: Int32 = -1
    private let partialSuffixes = ["download", "crdownload", "part", "tmp", "partial"]

    func start() {
        guard let folder else { return }
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
                  !partialSuffixes.contains((name as NSString).pathExtension.lowercased()) else { continue }
            let url = folder.appendingPathComponent(name)
            // Browsers rename the partial file into place, so a short delay avoids half-written files.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard FileManager.default.fileExists(atPath: url.path) else { return }
                self?.onNewFile?(url)
            }
        }
    }
}
