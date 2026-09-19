import AppKit
import EventKit
import SwiftUI

// MARK: - Pages

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
        case .battery: return "battery.100percent.bolt"
        case .connectivity: return "headphones"
        case .focus: return "moon.fill"
        case .display: return "sun.max.fill"
        case .sound: return "speaker.wave.2.fill"
        case .nowPlaying: return "waveform"
        case .calendar: return "calendar"
        case .shelf: return "tray.full.fill"
        case .lockScreen: return "lock.fill"
        case .extras: return "sparkles"
        case .about: return "info"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .battery: return .green
        case .connectivity: return .blue
        case .focus: return .indigo
        case .display: return .orange
        case .sound: return .pink
        case .nowPlaying: return .red
        case .calendar: return Color(red: 0.93, green: 0.27, blue: 0.27)
        case .shelf: return .brown
        case .lockScreen: return Color(white: 0.2)
        case .extras: return .purple
        case .about: return .teal
        }
    }

    /// One line under the master toggle of a feature page.
    var summary: String {
        switch self {
        case .general: return "How Islet sits on the notch and reacts to the pointer."
        case .battery: return "Peek when the charger connects, the charge runs low, or Low Power Mode changes."
        case .connectivity: return "Peek when AirPods, keyboards, mice, and controllers connect."
        case .focus: return "Peek when a Focus turns on or off."
        case .display: return "Replace the brightness and keyboard backlight bezels."
        case .sound: return "Replace the volume bezel."
        case .nowPlaying: return "Show the current track with artwork and a waveform."
        case .calendar: return "Show the next event and remind you before it starts."
        case .shelf: return "Park files in the notch and drag them out again."
        case .lockScreen: return "Sounds when the Mac locks and unlocks."
        case .extras: return "Small peeks and Shortcuts actions."
        case .about: return "Version, links, and credits."
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    @AppStorage("settingsSelectedPage") private var storedPage = SettingsPage.general.rawValue
    @State private var page: SettingsPage = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                row(.general)
                Section("Notifications") {
                    row(.battery)
                    row(.connectivity)
                    row(.focus)
                    row(.display)
                    row(.sound)
                }
                Section("Live Activities") {
                    row(.nowPlaying)
                    row(.calendar)
                    row(.shelf)
                    row(.lockScreen)
                }
                Section("Islet") {
                    row(.extras)
                    row(.about)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            pageView
                .navigationTitle(page.title)
        }
        .frame(minWidth: 760, minHeight: 600)
        .onAppear { page = SettingsPage(rawValue: storedPage) ?? .general }
        .onChange(of: page) { _, new in storedPage = new.rawValue }
    }

    private func row(_ page: SettingsPage) -> some View {
        HStack(spacing: 8) {
            SettingsIcon(page: page, size: 20)
            Text(page.title)
        }
        .padding(.vertical, 1)
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

/// A small colored rounded square with a white symbol, like the icons in System Settings.
struct SettingsIcon: View {
    let page: SettingsPage
    var size: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [page.color.opacity(0.98), page.color.opacity(0.78)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: page.symbol)
                    .font(.system(size: size * 0.54, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).strokeBorder(.black.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
            .accessibilityHidden(true)
    }
}

/// A title with an optional secondary line. Used as the label of toggles, pickers, and sliders.
struct SettingLabel: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Explanatory text that stands under a group of controls.
struct SettingFootnote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Medium-weight section title.
struct SectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.body.weight(.medium))
    }
}

/// The master toggle at the top of a feature page.
struct FeatureToggle: View {
    let page: SettingsPage
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsIcon(page: page, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title).font(.body.weight(.medium))
                    Text(page.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Monospaced value badge shown next to a slider.
struct ValueBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.quaternary))
            .frame(minWidth: 64, alignment: .trailing)
    }
}

/// A slider row with a monospaced value badge. Sliders share one width so rows line up.
struct SliderRow: View {
    let title: String
    var detail: String? = nil
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var unit: String
    var decimals = 1
    /// Show a leading sign, for offsets around zero.
    var signed = false

    private var formatted: String {
        let number = String(format: "%.\(decimals)f", value)
        let sign = signed && value > 0 ? "+" : ""
        return "\(sign)\(number) \(unit)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingLabel(title: title, detail: detail)
            Spacer(minLength: 16)
            Slider(value: $value, in: range, step: step)
                .frame(width: 200)
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue(formatted)
            ValueBadge(text: formatted)
        }
    }
}

/// `SliderRow` for integer settings.
struct IntSliderRow: View {
    let title: String
    var detail: String? = nil
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step = 1
    var unit: String

    var body: some View {
        SliderRow(title: title,
                  detail: detail,
                  value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                  range: Double(range.lowerBound)...Double(range.upperBound),
                  step: Double(step),
                  unit: unit,
                  decimals: 0)
    }
}

/// Toggle with a play button that previews the sound.
struct SoundRow: View {
    let title: String
    var detail: String? = nil
    let sound: IsletSound
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                SettingLabel(title: title, detail: detail)
                Spacer(minLength: 8)
                Button {
                    SoundPlayer.play(sound)
                } label: {
                    Image(systemName: "play.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Play the sound")
                .accessibilityLabel("Play \(title)")
            }
        }
    }
}

struct StyleOption: Identifiable {
    let id: String
    let label: String
}

/// Horizontal picker with a black preview pill per style and a ring around the selected one.
struct StylePicker<Preview: View>: View {
    let title: String
    @Binding var selection: String
    let options: [StyleOption]
    @ViewBuilder let preview: (String) -> Preview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
            HStack(spacing: 14) {
                ForEach(options) { option in
                    let selected = option.id == selection
                    Button {
                        withAnimation(.snappy(duration: 0.18)) { selection = option.id }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black)
                                preview(option.id).padding(.horizontal, 16)
                            }
                            .frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                                    .padding(-3)
                                    .opacity(selected ? 1 : 0)
                            )
                            Text(option.label)
                                .font(.callout)
                                .fontWeight(selected ? .semibold : .regular)
                                .foregroundStyle(selected ? .primary : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Picker for the HUD bar styles (white, accent, glow, decibel).
struct HUDStylePicker: View {
    let title: String
    @Binding var selection: String
    let options: [StyleOption]

    var body: some View {
        StylePicker(title: title, selection: $selection, options: options) { id in
            HUDBar(level: 0.62, style: id, showPercentage: false)
        }
    }
}

/// Picker for the waveform styles, with a preview that looks like the closed notch.
struct WaveformStylePicker: View {
    @Binding var selection: String

    private static let tint = Color(red: 0.98, green: 0.42, blue: 0.48)

    var body: some View {
        StylePicker(title: "Waveform style", selection: $selection, options: [
            StyleOption(id: "monochrome", label: "Monochrome"),
            StyleOption(id: "colored", label: "Colored"),
            StyleOption(id: "gradient", label: "Gradient"),
        ]) { id in
            HStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [Self.tint, Self.tint.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 20, height: 20)
                Spacer()
                Visualizer(playing: true, tint: Self.tint, style: id, height: 18)
            }
        }
    }
}

// MARK: - Permissions

enum PermissionStatus {
    case granted, denied, notAsked, perApp

    var label: String {
        switch self {
        case .granted: return "Allowed"
        case .denied: return "Not allowed"
        case .notAsked: return "Not asked yet"
        case .perApp: return "Asked per app"
        }
    }

    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .red
        case .notAsked: return .orange
        case .perApp: return .gray
        }
    }
}

enum SystemSettingsPane {
    static func open(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}

struct PermissionRow: View {
    let title: String
    let detail: String
    let status: PermissionStatus
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingLabel(title: title, detail: detail)
            Spacer(minLength: 16)
            HStack(spacing: 6) {
                Circle().fill(status.color).frame(width: 8, height: 8)
                Text(status.label).font(.callout).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Button(buttonTitle, action: action)
                .controlSize(.small)
        }
    }
}

// MARK: - General

struct GeneralPage: View {
    @Bindable var prefs = Preferences.shared
    @State private var launchAtLogin = Preferences.shared.launchAtLogin
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var calendarStatus = EKEventStore.authorizationStatus(for: .event)

    private var calendar: CalendarService? { AppDelegate.shared?.model?.calendar }

    private struct DisplayChoice: Identifiable {
        let id: String
        let name: String
    }

    private var screens: [DisplayChoice] {
        NSScreen.screens.compactMap { screen in
            guard let uuid = screen.displayUUID else { return nil }
            return DisplayChoice(id: uuid, name: screen.localizedName)
        }
    }

    private var calendarPermission: PermissionStatus {
        switch calendarStatus {
        case .fullAccess: return .granted
        case .denied, .restricted, .writeOnly: return .denied
        case .notDetermined: return .notAsked
        default: return .notAsked
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, new in
                        prefs.launchAtLogin = new
                        launchAtLogin = prefs.launchAtLogin
                    }
                Toggle(isOn: $prefs.hideInFullscreen) {
                    SettingLabel(title: "Hide in full screen apps", detail: "The notch stays out of the way while an app fills the screen.")
                }
                Toggle(isOn: $prefs.hideFromScreenCapture) {
                    SettingLabel(title: "Hide from screen capture", detail: "Screenshots and screen recordings do not include the island.")
                }
            }

            Section {
                Picker(selection: $prefs.displayTarget) {
                    Text("Automatic").tag("auto")
                    Text("Main display").tag("main")
                    Text("Built-in display").tag("builtin")
                    if !screens.isEmpty {
                        Divider()
                        ForEach(screens) { screen in
                            Text(screen.name).tag(screen.id)
                        }
                    }
                    if !isKnownDisplayTarget(prefs.displayTarget) {
                        Text("Disconnected display").tag(prefs.displayTarget)
                    }
                } label: {
                    SettingLabel(title: "Show on", detail: "Automatic picks the display with a notch, or the main display.")
                }
                Toggle(isOn: $prefs.simulatedNotch) {
                    SettingLabel(title: "Simulate a notch", detail: "Draw a notch on displays that do not have one.")
                }
            } header: {
                SectionTitle("Display")
            }

            Section {
                SliderRow(title: "Extra height", value: $prefs.notchHeightOffset, range: -2...4, step: 0.5, unit: "pt", signed: true)
                SliderRow(title: "Extra width", value: $prefs.notchWidthOffset, range: -4...8, step: 0.5, unit: "pt", signed: true)
            } header: {
                SectionTitle("Notch fit")
            } footer: {
                SettingFootnote("Panels differ by a point or so between units. Nudge these until the black band covers the notch exactly.")
            }

            Section {
                Toggle(isOn: $prefs.expandOnHover) {
                    SettingLabel(title: "Open on hover", detail: "Open the island when the pointer rests on the notch.")
                }
                SliderRow(title: "Hover delay", value: $prefs.hoverDelay, range: 0...1, step: 0.05, unit: "s", decimals: 2)
                    .disabled(!prefs.expandOnHover)
                Toggle(isOn: $prefs.gesturesEnabled) {
                    SettingLabel(title: "Trackpad gestures", detail: "Swipe down to open, swipe up to close. Swipe sideways over Now Playing to change tracks.")
                }
                Toggle(isOn: $prefs.globalHotkey) {
                    SettingLabel(title: "Keyboard shortcut", detail: "Press Control-Option-I to open or close the island from any app.")
                }
                Toggle("Haptic feedback", isOn: $prefs.hapticFeedback)
                Picker(selection: $prefs.animationSpeed) {
                    Text("Smooth").tag("smooth")
                    Text("Fast").tag("fast")
                    Text("Instant").tag("instant")
                } label: {
                    Text("Animation")
                }
                .pickerStyle(.segmented)
            } header: {
                SectionTitle("Interaction")
            }

            Section {
                Toggle(isOn: $prefs.contrastOutline) {
                    SettingLabel(title: "Contrast outline", detail: "Draw a thin edge so the island stands out on dark wallpapers.")
                }
                Toggle(isOn: $prefs.progressiveBlur) {
                    SettingLabel(title: "Progressive blur", detail: "Blur the content behind the open island.")
                }
            } header: {
                SectionTitle("Appearance")
            }

            Section {
                PermissionRow(title: "Calendar",
                              detail: "Needed to show the next event.",
                              status: calendarPermission,
                              buttonTitle: calendarPermission == .notAsked ? "Allow…" : "Open System Settings…") {
                    if calendarPermission == .notAsked, let calendar {
                        Task {
                            await calendar.requestAccess()
                            refreshPermissions()
                        }
                    } else {
                        SystemSettingsPane.open("Privacy_Calendars")
                    }
                }
                PermissionRow(title: "Accessibility",
                              detail: "Needed for the Caps Lock peek.",
                              status: accessibilityTrusted ? .granted : .denied,
                              buttonTitle: "Open System Settings…") {
                    if !accessibilityTrusted {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        _ = AXIsProcessTrustedWithOptions(options)
                    }
                    SystemSettingsPane.open("Privacy_Accessibility")
                }
                PermissionRow(title: "Automation",
                              detail: "Needed to ask a browser which tab is playing. macOS asks once per browser.",
                              status: .perApp,
                              buttonTitle: "Open System Settings…") {
                    SystemSettingsPane.open("Privacy_Automation")
                }
                PermissionRow(title: "System audio recording",
                              detail: "Needed for the live waveform. macOS asks when you turn it on.",
                              status: .perApp,
                              buttonTitle: "Open System Settings…") {
                    SystemSettingsPane.open("Privacy_AudioCapture")
                }
            } header: {
                SectionTitle("Permissions")
            } footer: {
                SettingFootnote("Islet checks these again each time the window comes to the front.")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshPermissions)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
    }

    private func isKnownDisplayTarget(_ target: String) -> Bool {
        ["auto", "main", "builtin"].contains(target) || screens.contains { $0.id == target }
    }

    private func refreshPermissions() {
        accessibilityTrusted = AXIsProcessTrusted()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }
}

// MARK: - Notifications

struct BatteryPage: View {
    @Bindable var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                FeatureToggle(page: .battery, isOn: $prefs.batteryEnabled)
            }
            Section {
                SliderRow(title: "Duration", value: $prefs.batteryDuration, range: 1...10, step: 0.5, unit: "s")
                Toggle("Peek when Low Power Mode changes", isOn: $prefs.batteryLowPowerMode)
                Toggle("Warn on low battery", isOn: $prefs.batteryWarnLow)
                IntSliderRow(title: "Low battery threshold", value: $prefs.batteryLowThreshold, range: 5...50, step: 5, unit: "%")
                    .disabled(!prefs.batteryWarnLow)
                SoundRow(title: "Play a sound", detail: "On charge and on low battery.", sound: .charging, isOn: $prefs.batterySound)
            } header: {
                SectionTitle("Peek")
            }
            Section {
                Toggle("Hide label", isOn: $prefs.batteryHideLabel)
                Toggle("Hide percentage", isOn: $prefs.batteryHidePercentage)
            } header: {
                SectionTitle("Content")
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
                FeatureToggle(page: .connectivity, isOn: $prefs.connectivityEnabled)
            }
            Section {
                SliderRow(title: "Duration", value: $prefs.connectivityDuration, range: 1...10, step: 0.5, unit: "s")
                Toggle("Warn on low accessory battery", isOn: $prefs.connectivityWarnLow)
                IntSliderRow(title: "Low battery threshold", value: $prefs.connectivityLowThreshold, range: 5...50, step: 5, unit: "%")
                    .disabled(!prefs.connectivityWarnLow)
                SoundRow(title: "Play a sound on connect", sound: .connected, isOn: $prefs.connectivitySound)
            } header: {
                SectionTitle("Peek")
            } footer: {
                SettingFootnote("Islet shows the battery level for accessories that report one.")
            }
            .disabled(!prefs.connectivityEnabled)
        }
        .formStyle(.grouped)
    }
}

struct FocusPage: View {
    @Bindable var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                FeatureToggle(page: .focus, isOn: $prefs.focusEnabled)
            }
            Section {
                SliderRow(title: "Duration", value: $prefs.focusDuration, range: 1...10, step: 0.5, unit: "s")
                SoundRow(title: "Play a sound", detail: "When the Sleep focus turns on.", sound: .focus, isOn: $prefs.focusSound)
                Toggle("Hide label", isOn: $prefs.focusHideLabel)
            } header: {
                SectionTitle("Peek")
            }
            .disabled(!prefs.focusEnabled)
        }
        .formStyle(.grouped)
    }
}

struct DisplayPage: View {
    @Bindable var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                FeatureToggle(page: .display, isOn: $prefs.displayHUDEnabled)
            }
            Section {
                SliderRow(title: "Duration", value: $prefs.displayHUDDuration, range: 0.5...5, step: 0.25, unit: "s", decimals: 2)
                HUDStylePicker(title: "Style", selection: $prefs.displayHUDStyle, options: [
                    StyleOption(id: "white", label: "White"),
                    StyleOption(id: "accent", label: "Accent"),
                    StyleOption(id: "glow", label: "Glow"),
                ])
                Toggle("Show percentage", isOn: $prefs.displayHUDPercentage)
                Toggle("Hide label", isOn: $prefs.displayHUDHideLabel)
            } header: {
                SectionTitle("Brightness")
            }
            .disabled(!prefs.displayHUDEnabled)
            Section {
                Toggle(isOn: $prefs.keyboardHUDEnabled) {
                    SettingLabel(title: "Keyboard backlight", detail: "Show the same bar when the backlight changes.")
                }
            } header: {
                SectionTitle("Keyboard")
            }
            .disabled(!prefs.displayHUDEnabled)
        }
        .formStyle(.grouped)
    }
}

struct SoundPage: View {
    @Bindable var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                FeatureToggle(page: .sound, isOn: $prefs.soundHUDEnabled)
            }
            Section {
                SliderRow(title: "Duration", value: $prefs.soundHUDDuration, range: 0.5...5, step: 0.25, unit: "s", decimals: 2)
                HUDStylePicker(title: "Style", selection: $prefs.soundHUDStyle, options: [
                    StyleOption(id: "white", label: "White"),
                    StyleOption(id: "accent", label: "Accent"),
                    StyleOption(id: "decibel", label: "Decibel"),
                ])
                Toggle("Show percentage", isOn: $prefs.soundHUDPercentage)
                Toggle("Hide label", isOn: $prefs.soundHUDHideLabel)
                Toggle(isOn: $prefs.soundHUDShowDevice) {
                    SettingLabel(title: "Show the output device", detail: "Use the icon of the current output device instead of a speaker.")
                }
            } header: {
                SectionTitle("Volume")
            }
            .disabled(!prefs.soundHUDEnabled)
            Section {
                Toggle(isOn: $prefs.replaceSystemHUD) {
                    SettingLabel(title: "Replace the system bezels", detail: "Pause the macOS bezel process so only Islet shows volume and brightness. Islet resumes it when this turns off or the app quits.")
                }
            } header: {
                SectionTitle("System")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Live Activities

struct NowPlayingPage: View {
    @Bindable var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                FeatureToggle(page: .nowPlaying, isOn: $prefs.nowPlayingEnabled)
            }
            Section {
                SliderRow(title: "Keep after pause", detail: "How long the track stays after playback pauses.", value: $prefs.nowPlayingIdleDuration, range: 0...60, step: 1, unit: "s", decimals: 0)
                Toggle(isOn: $prefs.nowPlayingSneakPeek) {
                    SettingLabel(title: "Peek the title", detail: "Show the title for a moment when a new track starts.")
                }
                Toggle(isOn: $prefs.hideWhileSourceActive) {
                    SettingLabel(title: "Hide while the source app is active", detail: "Do not show the track while the player app is in front.")
                }
                Toggle(isOn: $prefs.hideTitleExtras) {
                    SettingLabel(title: "Hide title extras", detail: "Drop suffixes such as (Official Video) or - Remastered.")
                }
            } header: {
                SectionTitle("Track")
            }
            .disabled(!prefs.nowPlayingEnabled)
            Section {
                WaveformStylePicker(selection: $prefs.waveformStyle)
                Toggle("Compact waveform in the closed notch", isOn: $prefs.compactWaveform)
                Toggle(isOn: $prefs.liveWaveform) {
                    SettingLabel(title: "Live waveform",
                                 detail: AudioLevelTap.isSupported
                                 ? "Animate the bars from the audio the Mac plays, through a CoreAudio tap. Nothing is recorded."
                                 : "Needs macOS 14.2 or later.")
                }
                .disabled(!AudioLevelTap.isSupported)
            } header: {
                SectionTitle("Waveform")
            }
            .disabled(!prefs.nowPlayingEnabled)
            Section {
                Toggle("Flip artwork on track change", isOn: $prefs.artworkFlip)
                Toggle(isOn: $prefs.siteIcons) {
                    SettingLabel(title: "Site icons for browser media", detail: "Ask the browser which tab plays and show that site's icon, for example YouTube or Netflix.")
                }
            } header: {
                SectionTitle("Artwork")
            }
            .disabled(!prefs.nowPlayingEnabled)
            Section {
                Toggle("Shuffle", isOn: $prefs.actionShuffle)
                Toggle("Repeat", isOn: $prefs.actionRepeat)
                Toggle("Copy title and artist", isOn: $prefs.actionCopy)
            } header: {
                SectionTitle("Actions")
            } footer: {
                SettingFootnote("Actions appear as buttons in the open island.")
            }
            .disabled(!prefs.nowPlayingEnabled)
        }
        .formStyle(.grouped)
    }
}

struct CalendarPage: View {
    @Bindable var prefs = Preferences.shared

    private var calendar: CalendarService? { AppDelegate.shared?.model?.calendar }

    private struct CalendarGroup: Identifiable {
        let source: String
        let calendars: [CalendarInfo]
        var id: String { source }
    }

    private var groupedCalendars: [CalendarGroup] {
        guard let calendar else { return [] }
        let groups = Dictionary(grouping: calendar.calendars, by: \.source)
        return groups.keys.sorted().map { CalendarGroup(source: $0, calendars: groups[$0] ?? []) }
    }

    var body: some View {
        Form {
            Section {
                FeatureToggle(page: .calendar, isOn: $prefs.calendarEnabled)
            }
            Section {
                IntSliderRow(title: "Remind before an event", value: $prefs.calendarReminderMinutes, range: 0...60, step: 5, unit: "min")
                SoundRow(title: "Play a sound for the reminder", sound: .calendar, isOn: $prefs.calendarSound)
                SoundRow(title: "Hourly chime", detail: "A short sound at the top of every hour.", sound: .chime, isOn: $prefs.hourlyChime)
                Toggle(isOn: $prefs.calendarUseColor) {
                    SettingLabel(title: "Use the calendar color", detail: "Tint the event with the color of its calendar.")
                }
            } header: {
                SectionTitle("Events")
            }
            .disabled(!prefs.calendarEnabled)
            if let calendar, calendar.authorized {
                ForEach(groupedCalendars) { group in
                    Section {
                        ForEach(group.calendars) { info in
                            Toggle(isOn: includeBinding(for: info.id)) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color(nsColor: info.color)).frame(width: 10, height: 10)
                                    Text(info.title)
                                }
                            }
                        }
                    } header: {
                        SectionTitle(group.source)
                    }
                    .disabled(!prefs.calendarEnabled)
                }
                if groupedCalendars.isEmpty {
                    Section {
                        SettingFootnote("No calendars found.")
                    } header: {
                        SectionTitle("Calendars")
                    }
                }
            } else if let calendar, calendar.denied {
                Section {
                    HStack {
                        SettingLabel(title: "Calendar access is off", detail: "Allow Islet under Privacy & Security › Calendars.")
                        Spacer()
                        Button("Open System Settings…") { SystemSettingsPane.open("Privacy_Calendars") }
                    }
                } header: {
                    SectionTitle("Calendars")
                }
            } else {
                Section {
                    HStack {
                        SettingLabel(title: "Calendar access", detail: "Islet reads events to show the next one in the notch.")
                        Spacer()
                        Button("Allow…") { Task { await calendar?.requestAccess() } }
                    }
                } header: {
                    SectionTitle("Calendars")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func includeBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { !prefs.calendarExcluded.contains(id) },
            set: { include in
                var excluded = Set(prefs.calendarExcluded)
                if include { excluded.remove(id) } else { excluded.insert(id) }
                prefs.calendarExcluded = excluded.sorted()
            })
    }
}

struct ShelfPage: View {
    @Bindable var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                FeatureToggle(page: .shelf, isOn: $prefs.shelfEnabled)
            } footer: {
                SettingFootnote("Drag files onto the notch to park them. Drag them back out anywhere, AirDrop them, double-click to open, or Quick Look from the context menu.")
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
                SoundRow(title: "Play a sound on lock", sound: .lock, isOn: $prefs.lockSoundOnLock)
                SoundRow(title: "Play a sound on unlock", sound: .unlock, isOn: $prefs.lockSoundOnUnlock)
            } header: {
                SectionTitle("Sounds")
            } footer: {
                SettingFootnote("Widgets on the lock screen itself are on the roadmap. Follow the GitHub repository for progress.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Islet

struct ExtrasPage: View {
    @Bindable var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $prefs.downloadsActivity) {
                    SettingLabel(title: "Finished downloads", detail: "Peek when a file lands in the Downloads folder.")
                }
                Toggle(isOn: $prefs.capsLockActivity) {
                    SettingLabel(title: "Caps Lock", detail: "Peek when Caps Lock turns on or off. Needs Accessibility access.")
                }
            } header: {
                SectionTitle("Peeks")
            }
            Section {
                SettingFootnote("Islet offers Toggle, Play/Pause, and Next Track actions to the Shortcuts app and Spotlight.")
            } header: {
                SectionTitle("Shortcuts")
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutPage: View {
    @State private var confirmReset = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "MIT License."
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Islet").font(.title2.weight(.semibold))
                        Text("Version \(version)").foregroundStyle(.secondary)
                        Text("A free Dynamic Island for the MacBook notch.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            Section {
                Link(destination: URL(string: "https://github.com/DevSrijit/islet")!) {
                    Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://github.com/DevSrijit/islet/releases")!) {
                    Label("Releases", systemImage: "arrow.down.circle")
                }
                Link(destination: URL(string: "https://github.com/DevSrijit/islet/issues")!) {
                    Label("Report a problem", systemImage: "exclamationmark.bubble")
                }
            } header: {
                SectionTitle("Links")
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MediaRemoteAdapter")
                    Text("Now Playing data comes from MediaRemoteAdapter by Jonas van den Berg, BSD 3-Clause.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(copyright)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                SectionTitle("Credits")
            }
            Section {
                HStack {
                    SettingLabel(title: "Reset all settings", detail: "Return every setting to its default. Launch at login and permissions stay as they are.")
                    Spacer()
                    Button("Reset…") { confirmReset = true }
                }
            } header: {
                SectionTitle("Reset")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset all settings?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { Preferences.shared.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every setting returns to its default. You cannot undo this.")
        }
    }
}
