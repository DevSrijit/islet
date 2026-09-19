import Foundation

/// Hides the built-in volume and brightness bezels so Islet can draw its own.
///
/// macOS draws those bezels from `OSDUIHelper`. Suspending that process with SIGSTOP stops the
/// bezels while leaving the keys working. We resume it again when the setting is turned off or
/// Islet quits. This is a well-known trick and it needs no special permissions.
final class SystemHUDSuppressor {
    static let shared = SystemHUDSuppressor()
    private var enabled = false
    private var wakeObserver: NSObjectProtocol?

    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        if on {
            suspend()
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.suspend() }
                }
        } else {
            resume()
            if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
            wakeObserver = nil
        }
    }

    private func suspend() {
        // Restart the helper so it is in a clean state, then freeze it.
        shell("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/com.apple.OSDUIHelper"])
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.signal("-STOP")
        }
    }

    private func resume() {
        signal("-CONT")
        shell("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/com.apple.OSDUIHelper"])
    }

    private func signal(_ flag: String) {
        shell("/usr/bin/killall", [flag, "OSDUIHelper"])
    }

    @discardableResult
    private func shell(_ path: String, _ arguments: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
    }
}

import AppKit
