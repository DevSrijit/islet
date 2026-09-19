import AppKit

/// A hardware key on the top row that macOS reports as a system-defined event.
enum MediaKey: Int {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case illuminationUp = 21
    case illuminationDown = 22

    enum Family { case sound, brightness, illumination }

    var family: Family {
        switch self {
        case .soundUp, .soundDown, .mute: return .sound
        case .brightnessUp, .brightnessDown: return .brightness
        case .illuminationUp, .illuminationDown: return .illumination
        }
    }
}

/// Reports presses of the volume, brightness, and keyboard backlight keys.
///
/// The keys arrive as `.systemDefined` events with subtype 8. The global monitor delivers them only
/// when the user granted Accessibility access, so callers must also work without any key event.
final class MediaKeyMonitor {
    static let shared = MediaKeyMonitor()

    private var handlers: [(MediaKey) -> Void] = []
    private var monitors: [Any] = []
    private var lastPress: [MediaKey.Family: Date] = [:]
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        let handle: (NSEvent) -> Void = { [weak self] event in self?.handle(event) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined, handler: handle) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .systemDefined, handler: { handle($0); return $0 }) {
            monitors.append(local)
        }
    }

    /// Adds a handler that runs on the main thread for every key down.
    func addHandler(_ handler: @escaping (MediaKey) -> Void) {
        handlers.append(handler)
    }

    /// True when a key of `family` went down within the last `interval` seconds.
    func pressed(_ family: MediaKey.Family, within interval: TimeInterval) -> Bool {
        guard let date = lastPress[family] else { return false }
        return Date().timeIntervalSince(date) <= interval
    }

    /// When a key of `family` last went down.
    func lastPress(of family: MediaKey.Family) -> Date? { lastPress[family] }

    private func handle(_ event: NSEvent) {
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }
        let data = event.data1
        let code = (data >> 16) & 0xFFFF
        let flags = (data >> 8) & 0xFF
        guard flags == 0x0A, let key = MediaKey(rawValue: code) else { return }
        lastPress[key.family] = Date()
        let handlers = self.handlers
        if Thread.isMainThread {
            handlers.forEach { $0(key) }
        } else {
            DispatchQueue.main.async { handlers.forEach { $0(key) } }
        }
    }
}
