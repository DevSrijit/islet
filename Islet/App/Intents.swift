import AppIntents

struct ToggleNotchIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Islet"
    static let description = IntentDescription("Opens or closes the Islet notch.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.model?.toggle()
        return .result()
    }
}

struct PlayPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Play or Pause Media"
    static let description = IntentDescription("Toggles playback for whatever is playing now.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.model?.media.togglePlayPause()
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Track"

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.model?.media.next()
        return .result()
    }
}

struct IsletShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ToggleNotchIntent(), phrases: ["Toggle \(.applicationName)"], shortTitle: "Toggle Islet", systemImageName: "rectangle.topthird.inset.filled")
        AppShortcut(intent: PlayPauseIntent(), phrases: ["Play or pause with \(.applicationName)"], shortTitle: "Play / Pause", systemImageName: "playpause.fill")
    }
}
