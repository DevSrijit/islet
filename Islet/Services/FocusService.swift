import Foundation

struct FocusMode: Equatable {
    let identifier: String
    let name: String
    let symbol: String
}

/// Watches the Focus database macOS keeps under ~/Library/DoNotDisturb.
///
/// There is no public API for the active Focus, but the system writes the active assertion and the
/// mode catalogue to two JSON files, so we watch that folder. The system replaces the folder now
/// and then, so the watcher reopens it when it goes away.
final class FocusService {
    var onChange: ((FocusMode?) -> Void)?
    private(set) var current: FocusMode?

    static let retryInterval: TimeInterval = 30

    private let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
    private var source: DispatchSourceFileSystemObject?
    private var debounce: DispatchWorkItem?
    private var retryTimer: Timer?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        current = read()
        watch()
    }

    /// Opens the folder and installs the file system source. Retries later when the folder is missing.
    private func watch() {
        source?.cancel(); source = nil
        retryTimer?.invalidate(); retryTimer = nil
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else {
            retryTimer = Timer.scheduledTimer(withTimeInterval: Self.retryInterval, repeats: false) { [weak self] _ in self?.watch() }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.source?.data ?? []
            self.scheduleRead()
            if flags.contains(.delete) || flags.contains(.rename) {
                // The folder itself moved. Reopen it once the system has written the new one.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.watch() }
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    private func scheduleRead() {
        debounce?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let new = self.read()
            guard new != self.current else { return }
            self.current = new
            self.onChange?(new)
        }
        debounce = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func read() -> FocusMode? {
        guard let assertions = json(folder.appendingPathComponent("Assertions.json")),
              let data = (assertions["data"] as? [[String: Any]])?.first,
              let records = data["storeAssertionRecords"] as? [[String: Any]],
              let record = records.first,
              let details = record["assertionDetails"] as? [String: Any],
              let identifier = details["assertionDetailsModeIdentifier"] as? String else { return nil }

        var name = "Focus"
        var symbol = "moon.fill"
        if let configs = json(folder.appendingPathComponent("ModeConfigurations.json")),
           let data = (configs["data"] as? [[String: Any]])?.first,
           let modes = data["modeConfigurations"] as? [String: Any],
           let config = modes[identifier] as? [String: Any],
           let mode = config["mode"] as? [String: Any] {
            name = mode["name"] as? String ?? name
            symbol = mode["symbolImageName"] as? String ?? symbol
        }
        return FocusMode(identifier: identifier, name: name, symbol: symbol)
    }

    private func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
