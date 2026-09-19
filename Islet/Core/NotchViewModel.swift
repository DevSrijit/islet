import AppKit
import Observation
import SwiftUI

enum NotchState: Equatable { case closed, open }

enum NotchTab: String, CaseIterable, Identifiable {
    case home, shelf
    var id: String { rawValue }
    var symbol: String { self == .home ? "house.fill" : "tray.full.fill" }
    var title: String { self == .home ? "Home" : "Shelf" }
}

/// Short-lived content shown in the closed notch (a "sneak peek").
enum TransientActivity: Equatable {
    case charging(percent: Int)
    case unplugged(percent: Int)
    case lowBattery(percent: Int)
    case lowPowerMode(on: Bool)
    case volume(level: Float, muted: Bool, deviceSymbol: String?)
    case brightness(level: Float)
    case keyboardBacklight(level: Float)
    case bluetooth(BluetoothEvent)
    case bluetoothLow(BluetoothEvent)
    case focus(name: String, symbol: String, on: Bool)
    case event(title: String, minutesLeft: Int, color: NSColor)
    case download(fileName: String)
    case capsLock(on: Bool)
    case track(title: String)
    case copied
    case dropHint

    var family: String {
        switch self {
        case .volume: return "volume"
        case .brightness: return "brightness"
        case .keyboardBacklight: return "keyboard"
        case .charging, .unplugged, .lowBattery, .lowPowerMode: return "battery"
        case .bluetooth, .bluetoothLow: return "bluetooth"
        case .focus: return "focus"
        case .event: return "event"
        case .download: return "download"
        case .capsLock: return "capslock"
        case .track: return "track"
        case .copied: return "copied"
        case .dropHint: return "drop"
        }
    }

    @MainActor
    var duration: TimeInterval {
        let p = Preferences.shared
        switch self {
        case .volume: return p.soundHUDDuration
        case .brightness, .keyboardBacklight: return p.displayHUDDuration
        case .charging, .unplugged, .lowBattery, .lowPowerMode: return p.batteryDuration
        case .bluetooth, .bluetoothLow: return p.connectivityDuration
        case .focus: return p.focusDuration
        case .event: return 6
        case .download: return 4
        case .capsLock: return 1.4
        case .track: return 2.6
        case .copied: return 1.2
        case .dropHint: return 60
        }
    }
}

@MainActor
@Observable
final class NotchViewModel {
    static let openWidth: CGFloat = 364
    static let openBodyHeight: CGFloat = 142
    /// How far the blur halo extends past the island before it fades out completely.
    static let haloFade: CGFloat = 56
    static let panelMargin = CGSize(width: 160, height: 150)

    // MARK: State
    var geometry: NotchGeometry
    var state: NotchState = .closed
    var tab: NotchTab = .home
    var isHovering = false
    var isDropTargeted = false
    var isDropSession = false
    var isScrubbing = false
    var hoverBump = false
    var isHidden = false

    var nowPlaying: NowPlaying?
    var showsMusicActivity = false
    var tint: Color = .white
    var battery: BatteryStatus?
    var focus: FocusMode?
    var transient: TransientActivity?
    var outputDeviceSymbol: String?
    var source: MediaSourceResolver.Source?

    let prefs = Preferences.shared
    let shelf = ShelfStore()
    let calendar = CalendarService()
    let media = NowPlayingService()
    let audioTap = AudioLevelTap()
    private let sourceResolver = MediaSourceResolver()

    // MARK: Services
    private let batteryService = BatteryService()
    private let volumeService = VolumeService()
    private let brightnessService = BrightnessService()
    private let bluetoothService = BluetoothService()
    private let downloadsService = DownloadsWatcher()
    private let capsLockService = CapsLockWatcher()
    private let focusService = FocusService()
    let systemState = SystemStateService()

    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var transientTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var lastTrackKey: String?
    private var horizontalScroll: CGFloat = 0
    private var verticalScroll: CGFloat = 0
    private var artworkTintCache: (Int, Color)?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    // MARK: Sizes

    /// Physical notch size plus the user's tuning, because panel tolerances vary by a point or so.
    var notchSize: CGSize {
        CGSize(width: geometry.notchSize.width + prefs.notchWidthOffset,
               height: geometry.notchSize.height + prefs.notchHeightOffset)
    }

    /// Measured widths of the content on each side of the physical notch while closed.
    /// The views report these, so the shape always fits whatever is in it.
    var closedLeading: CGFloat = 0
    var closedTrailing: CGFloat = 0

    var hasClosedContent: Bool { transient != nil || showsMusicActivity }

    /// Both sides always grow by the same amount, so the shape stays centred on the notch.
    var closedSide: CGFloat { hasClosedContent ? max(closedLeading, closedTrailing) : 0 }

    var closedSize: CGSize {
        CGSize(width: notchSize.width + 2 * closedSide, height: notchSize.height)
    }

    /// Kept for symmetry with the open state; the closed shape is always centred.
    var closedOffset: CGFloat { 0 }

    func reportClosedWidths(leading: CGFloat?, trailing: CGFloat?) {
        let l = leading ?? closedLeading, t = trailing ?? closedTrailing
        guard l != closedLeading || t != closedTrailing else { return }
        withAnimation(spring) { closedLeading = l; closedTrailing = t }
    }

    var openSize: CGSize {
        CGSize(width: max(Self.openWidth, notchSize.width + 2 * 92),
               height: notchSize.height + Self.openBodyHeight)
    }

    var currentSize: CGSize { state == .open ? openSize : closedSize }

    var panelSize: CGSize {
        CGSize(width: openSize.width + Self.panelMargin.width,
               height: openSize.height + Self.panelMargin.height)
    }

    var panelFrame: CGRect { geometry.rect(for: panelSize) }

    /// Site favicon for browser media, otherwise the source app's icon.
    var sourceIcon: NSImage? {
        if let icon = source?.icon { return icon }
        guard let bundle = nowPlaying?.appBundleID else { return nil }
        return NSImage.appIcon(bundleID: bundle)
    }
    var shapeScreenRect: CGRect {
        var rect = geometry.rect(for: currentSize)
        if state == .closed { rect.origin.x += closedOffset }
        return rect
    }

    var spring: Animation {
        switch prefs.animationSpeed {
        case "smooth": return .spring(duration: 0.6, bounce: 0.28)
        case "instant": return .spring(duration: 0.18, bounce: 0.0)
        default: return .spring(duration: 0.42, bounce: 0.22)
        }
    }

    // MARK: Lifecycle

    func start() {
        media.onUpdate = { [weak self] playing in self?.apply(nowPlaying: playing) }
        media.start()

        batteryService.onChange = { [weak self] old, new in self?.batteryChanged(from: old, to: new) }
        batteryService.start()

        volumeService.onChange = { [weak self] level, muted in
            guard let self, self.prefs.soundHUDEnabled else { return }
            let symbol = self.prefs.soundHUDShowDevice ? AudioDeviceInfo.defaultOutput()?.symbol : nil
            self.show(.volume(level: level, muted: muted, deviceSymbol: symbol))
        }
        volumeService.start()

        brightnessService.onDisplayChange = { [weak self] level in
            guard let self, self.prefs.displayHUDEnabled else { return }
            self.show(.brightness(level: level))
        }
        brightnessService.onKeyboardChange = { [weak self] level in
            guard let self, self.prefs.keyboardHUDEnabled else { return }
            self.show(.keyboardBacklight(level: level))
        }
        brightnessService.start()

        bluetoothService.onEvent = { [weak self] event in
            guard let self, self.prefs.connectivityEnabled else { return }
            self.show(.bluetooth(event))
            if self.prefs.connectivitySound { SoundPlayer.play(event.connected ? .connected : .disconnected) }
        }
        bluetoothService.onLowBattery = { [weak self] event in
            guard let self, self.prefs.connectivityEnabled, self.prefs.connectivityWarnLow else { return }
            self.show(.bluetoothLow(event))
            if self.prefs.connectivitySound { SoundPlayer.play(.lowBattery) }
        }
        bluetoothService.start()

        focusService.onChange = { [weak self] mode in
            guard let self else { return }
            let previous = self.focus
            self.focus = mode
            guard self.prefs.focusEnabled else { return }
            if let mode {
                self.show(.focus(name: mode.name, symbol: mode.symbol, on: true))
                if self.prefs.focusSound, mode.identifier.contains("sleep") { SoundPlayer.play(.focus) }
            } else if let previous {
                self.show(.focus(name: previous.name, symbol: previous.symbol, on: false))
            }
        }
        focusService.start()
        focus = nil

        downloadsService.onNewFile = { [weak self] url in
            guard let self, self.prefs.downloadsActivity else { return }
            self.show(.download(fileName: url.lastPathComponent))
        }
        downloadsService.start()

        capsLockService.onChange = { [weak self] on in
            guard let self, self.prefs.capsLockActivity else { return }
            self.show(.capsLock(on: on))
        }
        capsLockService.start()

        calendar.onUpcoming = { [weak self] event, minutes in
            guard let self, self.prefs.calendarEnabled else { return }
            self.show(.event(title: event.title, minutesLeft: minutes, color: event.color))
            if self.prefs.calendarSound { SoundPlayer.play(.calendar) }
        }
        calendar.onHour = { SoundPlayer.play(.chime) }
        if prefs.calendarEnabled { calendar.start() }

        systemState.onLockChange = { [weak self] locked in
            guard let self else { return }
            if locked, self.prefs.lockSoundOnLock { SoundPlayer.play(.lock) }
            if !locked, self.prefs.lockSoundOnUnlock { SoundPlayer.play(.unlock) }
            if locked { self.close() }
        }
        systemState.onLowPowerChange = { [weak self] on in
            guard let self, self.prefs.batteryEnabled, self.prefs.batteryLowPowerMode else { return }
            self.show(.lowPowerMode(on: on))
        }
        systemState.onFullscreenChange = { [weak self] full in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.25)) { self.isHidden = full && self.prefs.hideInFullscreen }
            self.updateAudioTap()
        }
        systemState.start()

        SystemHUDSuppressor.shared.setEnabled(prefs.replaceSystemHUD)
    }

    func stop() {
        media.stop()
        SystemHUDSuppressor.shared.setEnabled(false)
    }

    // MARK: Open / close

    func open(tab: NotchTab? = nil) {
        openTask?.cancel(); openTask = nil
        closeTask?.cancel(); closeTask = nil
        if let tab { self.tab = tab }
        guard state != .open else { return }
        withAnimation(spring) { state = .open; hoverBump = false }
        Haptics.play(.alignment)
    }

    func close() {
        openTask?.cancel(); openTask = nil
        closeTask?.cancel(); closeTask = nil
        guard state != .closed else { return }
        withAnimation(spring) { state = .closed }
        isScrubbing = false
        Haptics.play(.levelChange)
    }

    func toggle() { state == .open ? close() : open() }

    private func scheduleOpen() {
        guard openTask == nil, state == .closed, prefs.expandOnHover else { return }
        let delay = prefs.hoverDelay
        openTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.openTask = nil
            guard self.isHovering else { return }
            self.open()
        }
    }

    private func scheduleClose(after delay: TimeInterval = 0.35) {
        guard closeTask == nil, state == .open else { return }
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.closeTask = nil
            guard !self.isHovering, !self.isDropSession, !self.isScrubbing, !self.isDropTargeted else { return }
            self.close()
        }
    }

    // MARK: Mouse

    func mouseMoved(to point: CGPoint) {
        guard !isHidden else { return }
        let rect = shapeScreenRect.insetBy(dx: -6, dy: -6)
        let inside = rect.contains(point)
        guard inside != isHovering else { return }
        isHovering = inside
        if inside {
            closeTask?.cancel(); closeTask = nil
            withAnimation(spring) { hoverBump = state == .closed }
            scheduleOpen()
        } else {
            openTask?.cancel(); openTask = nil
            withAnimation(spring) { hoverBump = false }
            scheduleClose()
        }
    }

    func mouseDown(at point: CGPoint) {
        guard state == .closed, !isHidden, shapeScreenRect.contains(point) else { return }
        open()
    }

    /// Two-finger trackpad scrolling over the notch.
    func scroll(deltaX: CGFloat, deltaY: CGFloat, phase: NSEvent.Phase, momentum: NSEvent.Phase) {
        guard prefs.gesturesEnabled, isHovering else { return }
        if phase == .began { horizontalScroll = 0; verticalScroll = 0 }
        guard momentum == [] else { return }
        horizontalScroll += deltaX
        verticalScroll += deltaY

        if state == .closed, verticalScroll > 24 {
            verticalScroll = 0
            open()
        } else if state == .open, verticalScroll < -40, !isScrubbing {
            verticalScroll = 0
            close()
        }

        if state == .open, tab == .home, nowPlaying != nil, abs(horizontalScroll) > 70 {
            let forward = horizontalScroll < 0
            horizontalScroll = 0
            forward ? media.next() : media.previous()
            Haptics.play(.generic)
        }
    }

    // MARK: Drag & drop from other apps

    func dragEnteredNotch() {
        guard prefs.shelfEnabled, !isHidden else { return }
        isDropSession = true
        if state == .closed { show(.dropHint) }
        open(tab: .shelf)
    }

    func dragSessionEnded() {
        isDropSession = false
        if transient == .dropHint { clearTransient() }
        if !isHovering { scheduleClose(after: 0.6) }
    }

    // MARK: Transient activities

    func show(_ activity: TransientActivity) {
        transientTask?.cancel()
        withAnimation(spring) { transient = activity }
        let duration = activity.duration
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.clearTransient()
        }
    }

    func clearTransient() {
        transientTask?.cancel(); transientTask = nil
        withAnimation(spring) { transient = nil }
    }

    // MARK: Now playing

    func copyTrackInfo() {
        guard let nowPlaying else { return }
        let text = nowPlaying.artist.isEmpty ? nowPlaying.title : "\(nowPlaying.title) — \(nowPlaying.artist)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        Haptics.play(.generic)
    }

    func openSourceApp() {
        guard let id = nowPlaying?.appBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private func apply(nowPlaying new: NowPlaying?) {
        var new = new
        if prefs.hideTitleExtras, var track = new { track.title = track.title.strippingTitleExtras(); new = track }
        let key = new.map { "\($0.bundleID)|\($0.title)|\($0.artist)" }
        let changedTrack = key != lastTrackKey
        lastTrackKey = key
        withAnimation(spring) { nowPlaying = new }
        updateTint(for: new)
        updateMusicActivity()
        if changedTrack { resolveSource(for: new) }
        if changedTrack, let new, new.isPlaying, state == .closed, prefs.nowPlayingSneakPeek, prefs.nowPlayingEnabled, transient == nil {
            show(.track(title: new.title))
        }
    }

    private func resolveSource(for playing: NowPlaying?) {
        guard prefs.siteIcons, let playing, MediaSourceResolver.isBrowser(playing.appBundleID) else {
            withAnimation(spring) { source = nil }
            return
        }
        sourceResolver.resolve(bundleID: playing.appBundleID, title: playing.title) { [weak self] result in
            guard let self, self.nowPlaying?.title == playing.title else { return }
            withAnimation(self.spring) { self.source = result }
        }
    }

    /// Runs the audio tap only while the live waveform is visible, so it costs nothing otherwise.
    func updateAudioTap() {
        let wanted = prefs.liveWaveform && showsMusicActivity && (nowPlaying?.isPlaying ?? false) && !isHidden
        if wanted { audioTap.start() } else if audioTap.isRunning { audioTap.stop() }
    }

    /// The compact music activity stays for a while after playback pauses, then hides.
    private func updateMusicActivity() {
        defer { updateAudioTap() }
        idleTask?.cancel(); idleTask = nil
        guard prefs.nowPlayingEnabled, let nowPlaying else {
            withAnimation(spring) { showsMusicActivity = false }
            return
        }
        if prefs.hideWhileSourceActive, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == nowPlaying.appBundleID {
            withAnimation(spring) { showsMusicActivity = false }
            return
        }
        if nowPlaying.isPlaying {
            withAnimation(spring) { showsMusicActivity = true }
        } else {
            let idle = prefs.nowPlayingIdleDuration
            idleTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(idle))
                guard !Task.isCancelled, let self else { return }
                withAnimation(self.spring) { self.showsMusicActivity = false }
                self.updateAudioTap()
            }
        }
    }

    private func updateTint(for playing: NowPlaying?) {
        guard prefs.waveformStyle != "monochrome", let data = playing?.artworkData else {
            withAnimation(.easeInOut(duration: 0.4)) { tint = .white }
            return
        }
        let hash = data.hashValue
        if let cached = artworkTintCache, cached.0 == hash { tint = cached.1; return }
        Task.detached(priority: .utility) { [weak self] in
            let color = NSImage(data: data)?.dominantTint() ?? .white
            await MainActor.run {
                guard let self else { return }
                self.artworkTintCache = (hash, color)
                withAnimation(.easeInOut(duration: 0.5)) { self.tint = color }
            }
        }
    }

    private func batteryChanged(from old: BatteryStatus?, to new: BatteryStatus?) {
        battery = new
        guard prefs.batteryEnabled, let new, let old else { return }
        if new.isPluggedIn && !old.isPluggedIn {
            show(.charging(percent: new.percent))
            if prefs.batterySound { SoundPlayer.play(.charging) }
            Haptics.play(.generic)
        }
        if !new.isPluggedIn && old.isPluggedIn { show(.unplugged(percent: new.percent)) }
        let threshold = prefs.batteryLowThreshold
        if prefs.batteryWarnLow, !new.isPluggedIn, new.percent <= threshold, old.percent > threshold {
            show(.lowBattery(percent: new.percent))
            if prefs.batterySound { SoundPlayer.play(.lowBattery) }
        }
    }

    func preferencesChanged(key: String) {
        switch key {
        case "replaceSystemHUD": SystemHUDSuppressor.shared.setEnabled(prefs.replaceSystemHUD)
        case "calendarEnabled": prefs.calendarEnabled ? calendar.start() : calendar.stop()
        case "calendarExcluded", "calendarReminderMinutes": calendar.refresh()
        case "waveformStyle": updateTint(for: nowPlaying)
        case "nowPlayingEnabled", "hideWhileSourceActive", "nowPlayingIdleDuration": updateMusicActivity()
        case "hideInFullscreen": isHidden = systemState.isFullscreen && prefs.hideInFullscreen; updateAudioTap()
        case "liveWaveform": updateAudioTap()
        case "siteIcons": resolveSource(for: nowPlaying)
        default: break
        }
    }
}

extension String {
    /// Removes "(Official Video)", "[Lyrics]", "- Remastered 2011" and similar suffixes.
    func strippingTitleExtras() -> String {
        var result = self
        let patterns = [
            #"\s*[\(\[][^\)\]]*(official|video|lyric|audio|remaster|remastered|live|version|edit|mix|feat\.?|ft\.?|explicit|clean|hd|4k|visualizer)[^\)\]]*[\)\]]"#,
            #"\s+-\s+(official|remaster|remastered|live|radio edit|single version|album version).*$"#,
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? self : trimmed
    }
}
