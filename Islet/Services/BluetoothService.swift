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

    /// Registration replays every device that is already connected. Those are not news.
    static let replayWindow: TimeInterval = 3
    /// AirPods and some headsets open several links in a row. One report per device is enough.
    static let duplicateWindow: TimeInterval = 5

    private var pollTimer: Timer?
    private var warned: Set<String> = []
    private var startedAt = Date()
    private var lastReport: [String: (connected: Bool, at: Date)] = [:]
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        startedAt = Date()
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        pollTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.checkLowBattery() }
        pollTimer?.tolerance = 10
    }

    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
        guard Date().timeIntervalSince(startedAt) > Self.replayWindow else { return }
        let key = Self.key(for: device)
        // Battery values arrive a moment after the link comes up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, device.isConnected() else { return }
            self.report(Self.event(for: device, connected: true), key: key)
        }
    }

    @objc private func disconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        let key = Self.key(for: device)
        warned.remove(key)
        report(Self.event(for: device, connected: false), key: key)
    }

    /// Drops a repeat of the same report for the same device within the duplicate window.
    private func report(_ event: BluetoothEvent, key: String) {
        let now = Date()
        if let last = lastReport[key], last.connected == event.connected, now.timeIntervalSince(last.at) < Self.duplicateWindow {
            return
        }
        lastReport[key] = (event.connected, now)
        onEvent?(event)
    }

    private func checkLowBattery() {
        let threshold = Preferences.readConnectivityThreshold()
        guard threshold > 0, let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for device in devices where device.isConnected() {
            let event = Self.event(for: device, connected: true)
            let key = Self.key(for: device)
            guard let level = event.battery else { continue }
            if level <= threshold, !warned.contains(key) {
                warned.insert(key)
                onLowBattery?(event)
            } else if level > threshold + 5 {
                warned.remove(key)
            }
        }
    }

    private static func key(for device: IOBluetoothDevice) -> String {
        device.addressString ?? device.name ?? "unknown"
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
