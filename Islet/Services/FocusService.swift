import Foundation

struct FocusMode: Equatable {
    let identifier: String
    let name: String
    let symbol: String
}

/// Watches the Focus database macOS keeps under ~/Library/DoNotDisturb.
///
/// There is no public API for the active Focus, but the system writes the active assertion and the
/// mode catalogue to two JSON files, so we watch that folder.
final class FocusService {
    var onChange: ((FocusMode?) -> Void)?
    private(set) var current: FocusMode?

    private let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private var debounce: DispatchWorkItem?

    func start() {
        current = read()
        descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleRead() }
        source.setCancelHandler { [descriptor] in close(descriptor) }
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
