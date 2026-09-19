import AppKit
import Foundation

/// A snapshot of what the system reports as "Now Playing".
struct NowPlaying: Equatable {
    var bundleID: String
    var parentBundleID: String?
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    var duration: TimeInterval?
    var elapsed: TimeInterval?
    var timestamp: Date?
    var playbackRate: Double
    var artworkData: Data?
    /// 1 = off, 2 = albums, 3 = tracks.
    var shuffleMode: Int
    /// 1 = off, 2 = one track, 3 = all.
    var repeatMode: Int

    var shuffleOn: Bool { shuffleMode > 1 }

    /// The bundle that owns the media session. Browsers report a helper process, so prefer the parent.
    var appBundleID: String { parentBundleID ?? bundleID }

    /// Best estimate of the playhead position right now.
    func position(at now: Date = .now) -> TimeInterval? {
        guard let elapsed else { return nil }
        guard isPlaying, let timestamp else { return elapsed }
        let position = elapsed + now.timeIntervalSince(timestamp) * playbackRate
        if let duration { return min(max(position, 0), duration) }
        return max(position, 0)
    }
}

/// Reads Now Playing state through the bundled MediaRemoteAdapter.
///
/// The adapter runs inside the system Perl interpreter, which macOS 15.4+ still lets talk to
/// the private MediaRemote framework. We stream JSON lines from it and apply diffs.
final class NowPlayingService {
    var onUpdate: ((NowPlaying?) -> Void)?

    private var process: Process?
    private var buffer = Data()
    private var state: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.devsrijit.islet.nowplaying")
    private var shouldRun = false
    private var artworkCache: (String, Data)?

    private static let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")
    private static let frameworkURL = Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework")

    static var isAvailable: Bool { scriptURL != nil && frameworkURL != nil }

    func start() {
        shouldRun = true
        launch()
    }

    func stop() {
        shouldRun = false
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
    }

    // MARK: Commands

    func play() { send(0) }
    func pause() { send(1) }
    func togglePlayPause() { send(2) }
    func next() { send(4) }
    func previous() { send(5) }

    func seek(to seconds: TimeInterval) {
        let micros = Int(max(seconds, 0) * 1_000_000)
        run(arguments: ["seek", String(micros)])
    }

    func setShuffle(on: Bool) { run(arguments: ["shuffle", on ? "3" : "1"]) }

    /// Off -> all -> one -> off, the same order Music.app uses.
    func cycleRepeat(from mode: Int) {
        let next = mode <= 1 ? 3 : (mode == 3 ? 2 : 1)
        run(arguments: ["repeat", String(next)])
    }

    private func send(_ command: Int) {
        run(arguments: ["send", String(command)])
    }

    /// Runs a one-shot adapter command and forgets about it.
    private func run(arguments: [String]) {
        guard let script = Self.scriptURL, let framework = Self.frameworkURL else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script.path, framework.path] + arguments
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }

    // MARK: Streaming

    private func launch() {
        guard shouldRun, let script = Self.scriptURL, let framework = Self.frameworkURL else {
            NSLog("Islet: MediaRemoteAdapter is missing from the bundle")
            return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script.path, framework.path, "stream", "--debounce=80"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            self.queue.async { self.consume(data) }
        }
        p.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            guard let self, self.shouldRun else { return }
            self.queue.async {
                self.state = [:]
                self.publish()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.launch() }
        }
        do {
            try p.run()
            process = p
        } catch {
            NSLog("Islet: could not start MediaRemoteAdapter: \(error)")
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  object["type"] as? String == "data",
                  let payload = object["payload"] as? [String: Any] else { continue }
            let diff = object["diff"] as? Bool ?? false
            if diff {
                for (key, value) in payload {
                    if value is NSNull { state.removeValue(forKey: key) } else { state[key] = value }
                }
            } else {
                state = payload
            }
            publish()
        }
    }

    private func publish() {
        let snapshot = build()
        DispatchQueue.main.async { [onUpdate] in onUpdate?(snapshot) }
    }

    private func build() -> NowPlaying? {
        guard let bundle = state["bundleIdentifier"] as? String,
              let title = state["title"] as? String, !title.isEmpty else { return nil }
        var artwork: Data?
        if let base64 = state["artworkData"] as? String {
            if let cached = artworkCache, cached.0 == base64 {
                artwork = cached.1
            } else if let decoded = Data(base64Encoded: base64) {
                artworkCache = (base64, decoded)
                artwork = decoded
            }
        }
        var timestamp: Date?
        if let string = state["timestamp"] as? String {
            timestamp = Self.iso8601Fractional.date(from: string) ?? Self.iso8601.date(from: string)
        }
        return NowPlaying(
            bundleID: bundle,
            parentBundleID: state["parentApplicationBundleIdentifier"] as? String,
            title: title,
            artist: state["artist"] as? String ?? "",
            album: state["album"] as? String ?? "",
            isPlaying: state["playing"] as? Bool ?? false,
            duration: (state["duration"] as? NSNumber)?.doubleValue,
            elapsed: (state["elapsedTime"] as? NSNumber)?.doubleValue,
            timestamp: timestamp,
            playbackRate: (state["playbackRate"] as? NSNumber)?.doubleValue ?? 1,
            artworkData: artwork,
            shuffleMode: (state["shuffleMode"] as? NSNumber)?.intValue ?? 1,
            repeatMode: (state["repeatMode"] as? NSNumber)?.intValue ?? 1
        )
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
