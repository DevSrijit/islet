import Foundation
import IOKit.ps

struct BatteryStatus: Equatable {
    var percent: Int
    var isCharging: Bool
    var isPluggedIn: Bool
    var minutesToFull: Int?
    var minutesToEmpty: Int?
}

/// Watches the internal battery through IOKit power source notifications.
final class BatteryService {
    var onChange: ((BatteryStatus?, BatteryStatus?) -> Void)?
    private(set) var current: BatteryStatus?
    private var source: CFRunLoopSource?

    func start() {
        current = Self.read()
        onChange?(nil, current)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { service.refresh() }
        }, context)?.takeRetainedValue() else { return }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func refresh() {
        let new = Self.read()
        guard new != current else { return }
        let old = current
        current = new
        onChange?(old, new)
    }

    static func read() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = max > 0 ? Int((Double(capacity) / Double(max) * 100).rounded()) : capacity
            let toFull = description[kIOPSTimeToFullChargeKey] as? Int ?? -1
            let toEmpty = description[kIOPSTimeToEmptyKey] as? Int ?? -1
            return BatteryStatus(
                percent: min(percent, 100),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                minutesToFull: toFull > 0 ? toFull : nil,
                minutesToEmpty: toEmpty > 0 ? toEmpty : nil
            )
        }
        return nil
    }
}
