import Foundation
import IOBluetooth

struct BluetoothEvent: Equatable {
    let name: String
    let symbol: String
    let connected: Bool
    let battery: Int?
    let left: Int?
    let right: Int?
    let caseBattery: Int?
}

/// Reports Bluetooth device connections, with battery levels when the device exposes them.
final class BluetoothService: NSObject {
    var onEvent: ((BluetoothEvent) -> Void)?
    var onLowBattery: ((BluetoothEvent) -> Void)?
    private var pollTimer: Timer?
    private var warned: Set<String> = []
    private var startedAt = Date()

    func start() {
        startedAt = Date()
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        pollTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.checkLowBattery() }
    }

    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
        // Registration replays every device that is already connected. Those are not news.
        guard Date().timeIntervalSince(startedAt) > 3 else { return }
        // Battery values arrive a moment after the link comes up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onEvent?(Self.event(for: device, connected: true))
        }
    }

    @objc private func disconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        warned.remove(device.addressString ?? "")
        onEvent?(Self.event(for: device, connected: false))
    }

    private func checkLowBattery() {
        let threshold = Preferences.readConnectivityThreshold()
        guard threshold > 0, let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for device in devices where device.isConnected() {
            let event = Self.event(for: device, connected: true)
            let key = device.addressString ?? event.name
            guard let level = event.battery else { continue }
            if level <= threshold, !warned.contains(key) {
                warned.insert(key)
                onLowBattery?(event)
            } else if level > threshold + 5 {
                warned.remove(key)
            }
        }
    }

    static func event(for device: IOBluetoothDevice, connected: Bool) -> BluetoothEvent {
        let name = device.name ?? "Bluetooth device"
        let symbol = AudioDeviceInfo.bluetoothSymbol(for: name, majorClass: Int(device.deviceClassMajor), minorClass: Int(device.deviceClassMinor))
        return BluetoothEvent(name: name, symbol: symbol, connected: connected,
                              battery: connected ? read(device, "batteryPercentCombined") ?? read(device, "batteryPercentSingle") : nil,
                              left: connected ? read(device, "batteryPercentLeft") : nil,
                              right: connected ? read(device, "batteryPercentRight") : nil,
                              caseBattery: connected ? read(device, "batteryPercentCase") : nil)
    }

    /// Private accessors that AirPods and other Apple accessories implement.
    private static func read(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: Selector(key)), let value = device.value(forKey: key) as? Int, value > 0 else { return nil }
        return value
    }
}

extension Preferences {
    /// Reads the threshold without touching the main actor, for background timers.
    nonisolated static func readConnectivityThreshold() -> Int {
        UserDefaults.standard.object(forKey: "connectivityWarnLow") as? Bool ?? true
            ? UserDefaults.standard.integer(forKey: "connectivityLowThreshold") : 0
    }
}
