import AppKit
import Foundation

/// Works out *where* browser media is playing from, so Islet can show a YouTube or Netflix icon
/// instead of a generic Safari or Chrome icon.
///
/// macOS only tells us the browser and the media title. We ask the browser (through AppleScript,
/// which prompts once for Automation access) for its open tabs, match the tab title, and fetch that
/// site's favicon at runtime. Icons are cached on disk, and nothing brand-specific ships in the app.
///
/// Every lookup runs on a background queue. Results, including misses, are cached per title so a
/// track that keeps reporting the same title never runs the AppleScript twice.
final class MediaSourceResolver {
    struct Source: Equatable {
        let host: String
        let name: String
        let icon: NSImage?
    }

    static let browsers: [String: (app: String, titleProperty: String)] = [
        "com.apple.Safari": ("Safari", "name"),
        "com.apple.SafariTechnologyPreview": ("Safari Technology Preview", "name"),
        "com.google.Chrome": ("Google Chrome", "title"),
        "com.google.Chrome.canary": ("Google Chrome Canary", "title"),
        "com.brave.Browser": ("Brave Browser", "title"),
        "com.microsoft.edgemac": ("Microsoft Edge", "title"),
        "company.thebrowser.Browser": ("Arc", "title"),
        "com.vivaldi.Vivaldi": ("Vivaldi", "title"),
        "com.operasoftware.Opera": ("Opera", "title"),
    ]

    /// How long a miss (no matching tab) stays cached before the browser is asked again.
    static let missLifetime: TimeInterval = 120
    /// How long a failed favicon download stays cached.
    static let faviconMissLifetime: TimeInterval = 600
    private static let maxCachedResults = 64

    private let queue = DispatchQueue(label: "com.devsrijit.islet.source", qos: .utility)
    // Everything below is touched on `queue` only.
    private var memory: [String: NSImage] = [:]
    private var faviconMisses: [String: Date] = [:]
    private var results: [String: (source: Source?, at: Date)] = [:]
    private var resultOrder: [String] = []

    private var cacheFolder: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("com.devsrijit.Islet/favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func isBrowser(_ bundleID: String) -> Bool { browsers[bundleID] != nil }

    /// Resolves on a background queue and calls back on the main thread.
    func resolve(bundleID: String, title: String, completion: @escaping (Source?) -> Void) {
        guard let browser = Self.browsers[bundleID] else { completion(nil); return }
        let key = "\(bundleID)|\(title)"
        queue.async { [weak self] in
            guard let self else { return }
            if let cached = self.results[key], cached.source != nil || Date().timeIntervalSince(cached.at) < Self.missLifetime {
                DispatchQueue.main.async { completion(cached.source) }
                return
            }
            let host = self.matchingHost(browser: browser, title: title)
            var source: Source?
            if let host {
                source = Source(host: host, name: Self.displayName(for: host), icon: self.favicon(for: host))
            }
            self.remember(key: key, source: source)
            DispatchQueue.main.async { completion(source) }
        }
    }

    private func remember(key: String, source: Source?) {
        if results[key] == nil { resultOrder.append(key) }
        results[key] = (source, Date())
        while resultOrder.count > Self.maxCachedResults {
            results.removeValue(forKey: resultOrder.removeFirst())
        }
    }

    // MARK: Tabs

    private func matchingHost(browser: (app: String, titleProperty: String), title: String) -> String? {
        // Inside a `tell` block the word `tab` means the browser's tab class, so use a plain marker.
        let script = """
        set sep to " ~~ "
        set out to ""
        tell application "\(browser.app)"
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        set out to out & (URL of t) & sep & (\(browser.titleProperty) of t) & linefeed
                    end try
                end repeat
            end repeat
        end tell
        return out
        """
        guard let output = Self.runAppleScript(script) else { return nil }
        let needle = title.lowercased()
        var fallback: String?
        for line in output.split(separator: "\n") {
            let parts = line.components(separatedBy: " ~~ ")
            guard parts.count == 2, let url = URL(string: parts[0]), let host = url.host else { continue }
            let tabTitle = parts[1].lowercased()
            if tabTitle.contains(needle) || needle.contains(tabTitle) { return Self.normalize(host) }
            if fallback == nil, Self.knownMediaHosts.contains(where: { host.hasSuffix($0) }) { fallback = Self.normalize(host) }
        }
        return fallback
    }

    /// Runs the script through osascript so a slow or blocked browser can never stall the app.
    private static func runAppleScript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { Log.debug("osascript failed to start: \(error)"); return nil }
        input.fileHandleForWriting.write(source.data(using: .utf8) ?? Data())
        try? input.fileHandleForWriting.close()
        // Read before waiting, else a long tab list fills the pipe and the script never exits.
        var data = Data()
        let reader = DispatchGroup()
        reader.enter()
        DispatchQueue.global(qos: .utility).async {
            data = output.fileHandleForReading.readDataToEndOfFile()
            reader.leave()
        }
        if reader.wait(timeout: .now() + 4) == .timedOut {
            process.terminate()
            Log.debug("tab lookup timed out")
            return nil
        }
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    private static let knownMediaHosts = ["youtube.com", "netflix.com", "music.youtube.com", "open.spotify.com", "music.apple.com",
                                          "soundcloud.com", "twitch.tv", "primevideo.com", "disneyplus.com", "hbomax.com", "max.com",
                                          "hulu.com", "vimeo.com", "tv.apple.com", "bandcamp.com", "tidal.com", "deezer.com", "crunchyroll.com"]

    private static func normalize(_ host: String) -> String {
        var h = host.lowercased()
        if h.hasPrefix("www.") { h.removeFirst(4) }
        return h
    }

    static func displayName(for host: String) -> String {
        let known: [String: String] = ["youtube.com": "YouTube", "music.youtube.com": "YouTube Music", "netflix.com": "Netflix",
                                       "open.spotify.com": "Spotify", "music.apple.com": "Apple Music", "tv.apple.com": "Apple TV",
                                       "soundcloud.com": "SoundCloud", "twitch.tv": "Twitch", "primevideo.com": "Prime Video",
                                       "disneyplus.com": "Disney+", "max.com": "Max", "hulu.com": "Hulu", "vimeo.com": "Vimeo",
                                       "bandcamp.com": "Bandcamp", "tidal.com": "TIDAL", "deezer.com": "Deezer", "crunchyroll.com": "Crunchyroll"]
        if let name = known.first(where: { host.hasSuffix($0.key) })?.value { return name }
        let parts = host.split(separator: ".")
        let core = parts.count >= 2 ? String(parts[parts.count - 2]) : host
        return core.prefix(1).uppercased() + core.dropFirst()
    }

    // MARK: Favicons

    private func favicon(for host: String) -> NSImage? {
        if let cached = memory[host] { return cached }
        if let missedAt = faviconMisses[host], Date().timeIntervalSince(missedAt) < Self.faviconMissLifetime { return nil }
        let file = cacheFolder.appendingPathComponent(host + ".png")
        if let image = NSImage(contentsOf: file) { memory[host] = image; return image }
        let candidates = [
            "https://icons.duckduckgo.com/ip3/\(host).ico",
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate), let data = Self.download(url), data.count > 200,
                  let image = NSImage(data: data), image.size.width >= 16 else { continue }
            memory[host] = image
            faviconMisses.removeValue(forKey: host)
            if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: file)
            }
            return image
        }
        faviconMisses[host] = Date()
        return nil
    }

    /// Fetches with a short timeout. Runs on the resolver queue, never on the main thread.
    private static func download(_ url: URL) -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let done = DispatchSemaphore(value: 0)
        var result: Data?
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) { result = data }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 6)
        return result
    }
}

/// Minimal logger for errors. It writes to stderr, which is easy to capture when running the binary directly.
enum Log {
    static func debug(_ message: String) {
        FileHandle.standardError.write(("Islet: " + message + "\n").data(using: .utf8) ?? Data())
    }
}
