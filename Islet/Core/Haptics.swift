import AppKit

/// Thin wrapper over the Force Touch trackpad haptic engine.
enum Haptics {
    @MainActor
    static func play(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard Preferences.shared.hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
