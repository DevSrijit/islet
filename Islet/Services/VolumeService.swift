import CoreAudio
import Foundation

/// Listens for output volume and mute changes on the default output device.
///
/// One key press produces a burst of per-channel callbacks, so the service coalesces them into
/// one report. A volume key that cannot move the level (already at 0 or 100 percent) still reports
/// the current level, because the system bezel shows in that case too.
final class VolumeService {
    var onChange: ((Float, Bool) -> Void)?

    /// How long to wait for CoreAudio to report a change after a key press before reporting anyway.
    static let keyFallbackDelay: TimeInterval = 0.25

    private let keys: MediaKeyMonitor
    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var lastValue: (Float, Bool)?
    private var lastEmit: Date?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var pendingEmit: DispatchWorkItem?
    private var started = false

    // 'vmvc': virtual main volume. Works for devices that only expose per-channel volume.
    private static let virtualMainVolume: AudioObjectPropertySelector = 0x766D_7663

    init(keys: MediaKeyMonitor = .shared) {
        self.keys = keys
    }

    /// Current level and mute state of the default output device.
    var current: (level: Float, muted: Bool)? { lastValue.map { (level: $0.0, muted: $0.1) } }

    func start() {
        guard !started else { return }
        started = true
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.attachToDefaultDevice() }
        }
        defaultDeviceListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
        attachToDefaultDevice()
        keys.start()
        keys.addHandler { [weak self] key in self?.keyPressed(key) }
    }

    private func attachToDefaultDevice() {
        detach()
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return }
        deviceID = device

        let selectors: [(AudioObjectPropertySelector, AudioObjectPropertyElement)] = [
            (Self.virtualMainVolume, kAudioObjectPropertyElementMain),
            (kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyElementMain),
            (kAudioDevicePropertyVolumeScalar, 1),
            (kAudioDevicePropertyVolumeScalar, 2),
            (kAudioDevicePropertyMute, kAudioObjectPropertyElementMain),
        ]
        for (selector, element) in selectors {
            var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            guard AudioObjectHasProperty(device, &addr) else { continue }
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                DispatchQueue.main.async { self?.scheduleEmit() }
            }
            if AudioObjectAddPropertyListenerBlock(device, &addr, .main, block) == noErr {
                listeners.append((addr, block))
            }
        }
        // A device switch is not a user action, so remember the level without reporting it.
        lastValue = read()
    }

    private func detach() {
        guard deviceID != kAudioObjectUnknown else { return }
        for (addr, block) in listeners {
            var a = addr
            AudioObjectRemovePropertyListenerBlock(deviceID, &a, .main, block)
        }
        listeners.removeAll()
        deviceID = AudioDeviceID(kAudioObjectUnknown)
    }

    /// Coalesces the burst of per-channel callbacks a single key press produces.
    private func scheduleEmit() {
        pendingEmit?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let value = self.read() else { return }
            if let last = self.lastValue, abs(last.0 - value.0) < 0.001, last.1 == value.1 { return }
            self.lastValue = value
            self.emit(value)
        }
        pendingEmit = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: item)
    }

    /// Reports the current level after a volume key when CoreAudio reported no change.
    private func keyPressed(_ key: MediaKey) {
        guard key.family == .sound else { return }
        let pressedAt = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.keyFallbackDelay) { [weak self] in
            guard let self, self.lastEmit.map({ $0 < pressedAt }) ?? true, let value = self.read() else { return }
            self.lastValue = value
            self.emit(value)
        }
    }

    private func emit(_ value: (Float, Bool)) {
        lastEmit = Date()
        onChange?(value.0, value.1)
    }

    private func read() -> (Float, Bool)? {
        guard deviceID != kAudioObjectUnknown else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var found = false
        for (selector, element) in [(Self.virtualMainVolume, kAudioObjectPropertyElementMain),
                                    (kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyElementMain),
                                    (kAudioDevicePropertyVolumeScalar, AudioObjectPropertyElement(1))] {
            var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            if AudioObjectHasProperty(deviceID, &addr),
               AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &volume) == noErr {
                found = true
                break
            }
        }
        guard found, volume.isFinite else { return nil }
        var muted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &muteSize, &muted)
        }
        return (min(max(volume, 0), 1), muted != 0)
    }
}
