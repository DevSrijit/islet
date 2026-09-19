import AppKit

/// Named sounds Islet plays for events. Uses sounds that ship with macOS.
enum IsletSound: String, CaseIterable {
    case charging, lowBattery, connected, disconnected, focus, calendar, chime, lock, unlock, drop

    fileprivate var path: String {
        switch self {
        case .charging: return "/System/Library/CoreServices/PowerChime.app/Contents/Resources/connect_power.aif"
        case .lowBattery: return "/System/Library/Sounds/Basso.aiff"
        case .connected: return "/System/Library/Sounds/Hero.aiff"
        case .disconnected: return "/System/Library/Sounds/Bottle.aiff"
        case .focus: return "/System/Library/Sounds/Blow.aiff"
        case .calendar: return "/System/Library/Sounds/Glass.aiff"
        case .chime: return "/System/Library/Sounds/Ping.aiff"
        case .lock: return "/System/Library/Sounds/Tink.aiff"
        case .unlock: return "/System/Library/Sounds/Pop.aiff"
        case .drop: return "/System/Library/Sounds/Morse.aiff"
        }
    }
}

enum SoundPlayer {
    private static var cache: [IsletSound: NSSound] = [:]

    static func play(_ sound: IsletSound) {
        if cache[sound] == nil, let s = NSSound(contentsOfFile: sound.path, byReference: true) {
            cache[sound] = s
        }
        guard let s = cache[sound] else { return }
        s.stop()
        s.volume = 0.6
        s.play()
    }
}
