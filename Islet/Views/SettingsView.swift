import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, battery, connectivity, focus, display, sound, nowPlaying, calendar, shelf, lockScreen, extras, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .battery: return "Battery"
        case .connectivity: return "Connectivity"
        case .focus: return "Focus"
        case .display: return "Display"
        case .sound: return "Sound"
        case .nowPlaying: return "Now Playing"
        case .calendar: return "Calendar"
        case .shelf: return "Shelf"
        case .lockScreen: return "Lock Screen"
        case .extras: return "Extras"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .battery: return "bolt.fill"
        case .connectivity: return "headphones"
        case .focus: return "moon.fill"
        case .display: return "sun.max.fill"
        case .sound: return "speaker.wave.2.fill"
        case .nowPlaying: return "play.fill"
        case .calendar: return "calendar"
        case .shelf: return "tray.full.fill"
        case .lockScreen: return "lock.fill"
        case .extras: return "sparkles"
        case .about: return "info"
        }
    }

    var color: Color {
        switch self {
        case .general: return Color(white: 0.5)
        case .battery: return Color(red: 0.98, green: 0.55, blue: 0.25)
        case .connectivity: return Color(red: 0.25, green: 0.78, blue: 0.5)
        case .focus: return Color(red: 0.45, green: 0.45, blue: 0.95)
        case .display: return Color(red: 0.7, green: 0.45, blue: 0.95)
        case .sound: return Color(red: 0.9, green: 0.4, blue: 0.85)
        case .nowPlaying: return Color(red: 0.95, green: 0.3, blue: 0.35)
        case .calendar: return Color(red: 0.95, green: 0.3, blue: 0.3)
        case .shelf: return Color(white: 0.4)
        case .lockScreen: return Color(white: 0.15)
        case .extras: return Color(red: 0.2, green: 0.6, blue: 0.95)
        case .about: return Color(white: 0.55)
        }
    }
}

struct SettingsView: View {
    @State private var page: SettingsPage = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                row(.general)
                Section("Notifications") {
                    row(.battery); row(.connectivity); row(.focus); row(.display); row(.sound)
                }
                Section("Live Activities") {
                    row(.nowPlaying); row(.calendar); row(.shelf); row(.lockScreen)
                }
                Section("Islet") {
                    row(.extras); row(.about)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    SettingsIcon(page: page, size: 30)
                    Text(page.title).font(.title2.bold())
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 4)
                pageView
            }
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    private func row(_ page: SettingsPage) -> some View {
        HStack(spacing: 8) {
            SettingsIcon(page: page, size: 22)
            Text(page.title)
        }
        .tag(page)
    }

    @ViewBuilder
    private var pageView: some View {
        switch page {
        case .general: GeneralPage()
        case .battery: BatteryPage()
        case .connectivity: ConnectivityPage()
        case .focus: FocusPage()
        case .display: DisplayPage()
        case .sound: SoundPage()
        case .nowPlaying: NowPlayingPage()
        case .calendar: CalendarPage()
        case .shelf: ShelfPage()
        case .lockScreen: LockScreenPage()
        case .extras: ExtrasPage()
        case .about: AboutPage()
        }
    }
}

// MARK: - Building blocks

struct SettingsIcon: View {
    let page: SettingsPage
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(LinearGradient(colors: [page.color.opacity(0.95), page.color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: page.symbol)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
    }
}

/// A slider row with a value badge, like the ones in System Settings.
struct DurationRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var unit: String
    var decimals = 1

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value, specifier: "%.\(decimals)f") \(unit)")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary))
            }
            Slider(value: $value, in: range, step: step)
        }
        .padding(.vertical, 2)
    }
}

struct IntRow: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step = 1
    var unit: String

    var body: some View {
        DurationRow(title: title,
                    value: Binding(get: { Double(value) }, set: { value = Int($0) }),
                    range: Double(range.lowerBound)...Double(range.upperBound), step: Double(step), unit: unit, decimals: 0)
    }
}

/// Toggle with a small "play" button that previews the sound.
struct SoundRow: View {
    let title: String
    let sound: IsletSound
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 6) {
                Text(title)
                Button { SoundPlayer.play(sound) } label: {
                    Image(systemName: "play.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Preview")
            }
        }
    }
}

/// Horizontal picker with a black HUD preview per style.
struct HUDStylePicker: View {
    @Binding var selection: String
    var options: [(id: String, label: String)]
    var green = false

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.id) { option in
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black)
                        HUDBar(level: 0.62, style: option.id == "decibel" ? "decibel" : option.id, showPercentage: false)
                            .padding(.horizontal, 22)
                    }
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.accentColor, lineWidth: selection == option.id ? 2.5 : 0))
                    Text(option.label).font(.callout).fontWeight(selection == option.id ? .semibold : .regular)
                        .foregroundStyle(selection == option.id ? .primary : .secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { selection = option.id } }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SegmentPicker: View {
    @Binding var selection: String
    var options: [(id: String, label: String, symbol: String)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.id) { option in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selection == option.id ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                        .frame(height: 44)
                        .overlay(Image(systemName: option.symbol).font(.title3).foregroundStyle(selection == option.id ? Color.accentColor : .secondary))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.accentColor, lineWidth: selection == option.id ? 2.5 : 0))
                    Text(option.label).font(.callout).fontWeight(selection == option.id ? .semibold : .regular)
                        .foregroundStyle(selection == option.id ? .primary : .secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { selection = option.id } }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pages

struct GeneralPage: View {
    @Bindable var prefs = Preferences.shared
    @State private var launchAtLogin = Preferences.shared.launchAtLogin

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, new in prefs.launchAtLogin = new; launchAtLogin = prefs.launchAtLogin }
                Toggle("Hide in full screen apps", isOn: $prefs.hideInFullscreen)
                Toggle("Hide from screen capture", isOn: $prefs.hideFromScreenCapture)
                Toggle("Simulated notch on displays without one", isOn: $prefs.simulatedNotch)
                Picker("Display on", selection: $prefs.displayTarget) {
                    Text("Automatic").tag("auto")
                    Text("Main display").tag("main")
                    Text("Built-in display").tag("builtin")
                    ForEach(NSScreen.screens, id: \.localizedName) { screen in
                        if let uuid = screen.displayUUID { Text(screen.localizedName).tag(uuid) }
                    }
                }
            }
            Section("Notch fit") {
                DurationRow(title: "Extra height", value: $prefs.notchHeightOffset, range: -2...4, step: 0.5, unit: "pt")
                DurationRow(title: "Extra width", value: $prefs.notchWidthOffset, range: -4...8, step: 0.5, unit: "pt")
                Text("Panels differ by a point or so between units. Nudge these until the black band exactly covers the notch.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Behaviour") {
                Toggle("Contrast outline", isOn: $prefs.contrastOutline)
                Toggle("Progressive blur behind the island", isOn: $prefs.progressiveBlur)
                Toggle("Haptic feedback", isOn: $prefs.hapticFeedback)
                Toggle("Expand on hover", isOn: $prefs.expandOnHover)
                if prefs.expandOnHover {
                    DurationRow(title: "Hover delay", value: $prefs.hoverDelay, range: 0...1, step: 0.05, unit: "s", decimals: 2)
                }
                SegmentPicker(selection: $prefs.animationSpeed, options: [
                    ("smooth", "Smooth", "tortoise.fill"), ("fast", "Fast", "hare.fill"), ("instant", "Instant", "bolt.fill"),
                ])
            }
            Section("Gestures") {
                Toggle("Trackpad gestures", isOn: $prefs.gesturesEnabled)
                Text("Swipe down on the notch to open it, swipe up to close. Swipe left or right over Now Playing to change tracks.")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("Global shortcut  ⌃⌥I", isOn: $prefs.globalHotkey)
            }
        }
        .formStyle(.grouped)
    }
}

struct BatteryPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.batteryEnabled) { Label("Battery", systemImage: "bolt.fill") }
                DurationRow(title: "Duration", value: $prefs.batteryDuration, range: 1...10, step: 0.5, unit: "s")
                Toggle("Notify on Low Power Mode", isOn: $prefs.batteryLowPowerMode)
                Toggle("Warn on low battery", isOn: $prefs.batteryWarnLow)
                IntRow(title: "Low battery threshold", value: $prefs.batteryLowThreshold, range: 5...50, step: 5, unit: "%")
                SoundRow(title: "Play sound on charge and low battery", sound: .charging, isOn: $prefs.batterySound)
                Toggle("Hide label", isOn: $prefs.batteryHideLabel)
                Toggle("Hide percentage", isOn: $prefs.batteryHidePercentage)
            }
            .disabled(!prefs.batteryEnabled)
        }
        .formStyle(.grouped)
    }
}

struct ConnectivityPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.connectivityEnabled) { Label("Connectivity", systemImage: "headphones") }
                DurationRow(title: "Duration", value: $prefs.connectivityDuration, range: 1...10, step: 0.5, unit: "s")
                Toggle("Warn on low accessory battery", isOn: $prefs.connectivityWarnLow)
                IntRow(title: "Low battery threshold", value: $prefs.connectivityLowThreshold, range: 5...50, step: 5, unit: "%")
                SoundRow(title: "Play sound on connect", sound: .connected, isOn: $prefs.connectivitySound)
            }
            Section {
                Text("Islet shows AirPods, Beats, keyboards, mice and controllers when they connect, with battery levels for accessories that report them.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct FocusPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.focusEnabled) { Label("Focus", systemImage: "moon.fill") }
                DurationRow(title: "Duration", value: $prefs.focusDuration, range: 1...10, step: 0.5, unit: "s")
                SoundRow(title: "Play sound on Sleep focus", sound: .focus, isOn: $prefs.focusSound)
                Toggle("Hide label", isOn: $prefs.focusHideLabel)
            }
        }
        .formStyle(.grouped)
    }
}

struct DisplayPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.displayHUDEnabled) { Label("Brightness", systemImage: "sun.max.fill") }
                DurationRow(title: "Duration", value: $prefs.displayHUDDuration, range: 0.5...5, step: 0.25, unit: "s", decimals: 2)
                HUDStylePicker(selection: $prefs.displayHUDStyle, options: [("white", "White"), ("accent", "Accent"), ("glow", "Glow")])
                Toggle("Show percentage", isOn: $prefs.displayHUDPercentage)
                Toggle("Hide label", isOn: $prefs.displayHUDHideLabel)
                Toggle("Keyboard backlight", isOn: $prefs.keyboardHUDEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

struct SoundPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.soundHUDEnabled) { Label("Volume", systemImage: "speaker.wave.2.fill") }
                DurationRow(title: "Duration", value: $prefs.soundHUDDuration, range: 0.5...5, step: 0.25, unit: "s", decimals: 2)
                HUDStylePicker(selection: $prefs.soundHUDStyle, options: [("white", "White"), ("accent", "Accent"), ("decibel", "Decibel")])
                Toggle("Show percentage", isOn: $prefs.soundHUDPercentage)
                Toggle("Hide label", isOn: $prefs.soundHUDHideLabel)
                Toggle("Show output device instead of speaker symbol", isOn: $prefs.soundHUDShowDevice)
            }
            Section {
                Toggle("Replace the system volume and brightness bezels", isOn: $prefs.replaceSystemHUD)
                Text("Pauses the macOS bezel process so only Islet's HUDs show. Islet resumes it when this is turned off or the app quits.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct NowPlayingPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.nowPlayingEnabled) { Label("Now Playing", systemImage: "play.fill") }
                DurationRow(title: "Idle duration after pause", value: $prefs.nowPlayingIdleDuration, range: 0...60, step: 1, unit: "s", decimals: 0)
                Toggle("Peek the title when a track starts", isOn: $prefs.nowPlayingSneakPeek)
                HUDStylePicker(selection: $prefs.waveformStyle, options: [("monochrome", "Monochrome"), ("colored", "Colored"), ("gradient", "Gradient")])
            }
            Section("Waveform") {
                Toggle("Use live waveform", isOn: $prefs.liveWaveform)
                    .disabled(!AudioLevelTap.isSupported)
                Text(AudioLevelTap.isSupported
                     ? "Animates the bars from the audio the Mac is playing, through a CoreAudio tap. macOS asks once for System Audio Recording permission. Nothing is recorded."
                     : "Needs macOS 14.2 or later.")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("Compact waveform in the closed notch", isOn: $prefs.compactWaveform)
            }
            Section("Artwork") {
                Toggle("Flip artwork on track change", isOn: $prefs.artworkFlip)
                Toggle("Show site icons for browser media", isOn: $prefs.siteIcons)
                Text("Asks the browser which tab is playing (macOS prompts once per browser) and shows that site's icon, for example YouTube or Netflix.")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("Hide while the source app is active", isOn: $prefs.hideWhileSourceActive)
                Toggle("Hide media title extras", isOn: $prefs.hideTitleExtras)
            }
            Section("Actions") {
                Toggle("Shuffle", isOn: $prefs.actionShuffle)
                Toggle("Repeat", isOn: $prefs.actionRepeat)
                Toggle("Copy title and artist", isOn: $prefs.actionCopy)
            }
        }
        .formStyle(.grouped)
    }
}

struct CalendarPage: View {
    @Bindable var prefs = Preferences.shared
    private var calendar: CalendarService? { AppDelegate.shared?.model?.calendar }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.calendarEnabled) { Label("Calendar", systemImage: "calendar") }
                IntRow(title: "Time before event", value: $prefs.calendarReminderMinutes, range: 0...60, step: 5, unit: "m")
                SoundRow(title: "Play sound on calendar event", sound: .calendar, isOn: $prefs.calendarSound)
                SoundRow(title: "Play hourly chime", sound: .chime, isOn: $prefs.hourlyChime)
                Toggle("Use calendar colour", isOn: $prefs.calendarUseColor)
            }
            Section("Calendars") {
                if let calendar, calendar.authorized {
                    ForEach(calendar.calendars) { info in
                        Toggle(isOn: Binding(
                            get: { !prefs.calendarExcluded.contains(info.id) },
                            set: { on in
                                var excluded = Set(prefs.calendarExcluded)
                                if on { excluded.remove(info.id) } else { excluded.insert(info.id) }
                                prefs.calendarExcluded = Array(excluded)
                            })) {
                            HStack(spacing: 8) {
                                Circle().fill(Color(nsColor: info.color)).frame(width: 10, height: 10)
                                Text(info.title)
                                Text(info.source).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if let calendar, calendar.denied {
                    Text("Calendar access is off. Allow Islet under System Settings › Privacy & Security › Calendars.")
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                    }
                } else {
                    Button("Allow calendar access") { Task { await calendar?.requestAccess() } }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShelfPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.shelfEnabled) { Label("Shelf", systemImage: "tray.full.fill") }
                Text("Drag files onto the notch to park them. Drag them back out anywhere, AirDrop them, double-click to open, or Quick Look from the context menu.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct LockScreenPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section {
                SoundRow(title: "Play sound on lock", sound: .lock, isOn: $prefs.lockSoundOnLock)
                SoundRow(title: "Play sound on unlock", sound: .unlock, isOn: $prefs.lockSoundOnUnlock)
            }
            Section {
                Text("Widgets on the lock screen itself are on the roadmap. Follow the GitHub repository for progress.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct ExtrasPage: View {
    @Bindable var prefs = Preferences.shared
    var body: some View {
        Form {
            Section("Peeks") {
                Toggle("Finished downloads", isOn: $prefs.downloadsActivity)
                Toggle("Caps Lock", isOn: $prefs.capsLockActivity)
                Text("Caps Lock needs Accessibility access for Islet, because macOS only reports key state to trusted apps.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Shortcuts") {
                Text("Islet exposes Toggle, Play/Pause and Next Track actions to the Shortcuts app and Spotlight.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutPage: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Islet").font(.title2.bold())
                        Text("Version \(version)").foregroundStyle(.secondary)
                        Text("Free, open source, MIT licensed.").font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            Section {
                Link(destination: URL(string: "https://github.com/DevSrijit/islet")!) { Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                Link(destination: URL(string: "https://github.com/DevSrijit/islet/releases")!) { Label("Releases", systemImage: "arrow.down.circle") }
                Link(destination: URL(string: "https://github.com/DevSrijit/islet/issues")!) { Label("Report a problem", systemImage: "exclamationmark.bubble") }
            }
            Section("Thanks") {
                Text("Now Playing data comes from MediaRemoteAdapter by Jonas van den Berg (BSD 3-Clause).")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
