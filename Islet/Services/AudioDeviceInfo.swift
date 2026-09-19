import CoreAudio
import Foundation

/// Name and a matching SF Symbol for the default output device.
enum AudioDeviceInfo {
    struct OutputDevice: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
        let symbol: String
    }

    /// Every device that can play audio.
    static func outputDevices() -> [OutputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            let name = deviceName(id)
            guard !name.isEmpty else { return nil }
            return OutputDevice(id: id, name: name, symbol: symbol(for: name, transport: transportType(id)))
        }
    }

    static func setDefaultOutput(_ id: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &device)
    }

    private static func deviceName(_ id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0) }
        return status == noErr ? name as String : ""
    }

    private static func transportType(_ id: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transport)
        return transport
    }

    static func defaultOutput() -> (name: String, symbol: String)? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return nil }

        var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        withUnsafeMutablePointer(to: &name) { pointer in
            _ = AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &nameSize, pointer)
        }
        var transportAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var transport: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &transportAddress, 0, nil, &transportSize, &transport)

        let deviceName = name as String
        return (deviceName, symbol(for: deviceName, transport: transport))
    }

    static func symbol(for name: String, transport: UInt32) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("homepod") { return "homepod.fill" }
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeBuiltIn: return "laptopcomputer"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "tv"
        case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
        case kAudioDeviceTransportTypeUSB: return "hifispeaker.fill"
        default: return "speaker.wave.2.fill"
        }
    }

    /// Picks a symbol for a Bluetooth accessory from its advertised name.
    static func bluetoothSymbol(for name: String, majorClass: Int, minorClass: Int) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("magic mouse") { return "magicmouse.fill" }
        if lower.contains("trackpad") { return "rectangle.fill" }
        if lower.contains("keyboard") { return "keyboard.fill" }
        if lower.contains("iphone") { return "iphone" }
        if lower.contains("watch") { return "applewatch" }
        if lower.contains("controller") || lower.contains("dualsense") || lower.contains("xbox") { return "gamecontroller.fill" }
        switch majorClass {
        case 0x04: return "headphones"
        case 0x05:
            switch minorClass & 0x30 {
            case 0x10: return "keyboard.fill"
            case 0x20: return "computermouse.fill"
            default: return "gamecontroller.fill"
            }
        case 0x02: return "iphone"
        default: return "wave.3.right"
        }
    }
}
