import AppKit

/// Reports Caps Lock changes. The global monitor only fires once Accessibility access is granted.
final class CapsLockWatcher {
    var onChange: ((Bool) -> Void)?
    private var monitors: [Any] = []
    private var last = NSEvent.modifierFlags.contains(.capsLock)

    func start() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let on = event.modifierFlags.contains(.capsLock)
            guard on != self.last else { return }
            self.last = on
            self.onChange?(on)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { handler($0); return $0 }) {
            monitors.append(local)
        }
    }
}
