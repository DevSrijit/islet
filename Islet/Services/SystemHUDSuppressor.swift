import AppKit
import Foundation

/// Hides the built-in volume and brightness bezels so Islet can draw its own.
///
/// macOS draws those bezels from `OSDUIHelper`. Suspending that process with SIGSTOP stops the
/// bezels while leaving the keys working. The system restarts the helper after sleep and on its own
/// schedule, so the suppressor checks every 20 seconds that the helper is still stopped. It resumes
/// the helper when the setting is turned off and when Islet quits. This needs no special permissions.
final class SystemHUDSuppressor {
    static let shared = SystemHUDSuppressor()

    static let checkInterval: TimeInterval = 20
    private static let helperLabel = "com.apple.OSDUIHelper"
    private static let helperName = "OSDUIHelper"

    private let queue = DispatchQueue(label: "com.devsrijit.islet.hud-suppressor", qos: .utility)
    private var enabled = false
    private var wakeObserver: NSObjectProtocol?
    private var timer: Timer?

    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        if on {
            queue.async { self.suspend() }
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.ensureSuspended() }
                }
            timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
                self?.ensureSuspended()
            }
            timer?.tolerance = 2
        } else {
            timer?.invalidate(); timer = nil
            if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
            wakeObserver = nil
            queue.async { self.resume() }
        }
    }

    /// Resumes the helper and waits for it, so a quit never leaves the helper frozen.
    /// Safe to call more than once and from a signal handler on the main queue.
    func resumeForExit() {
        setEnabled(false)
        queue.sync {}
    }

    private func ensureSuspended() {
        guard enabled else { return }
        queue.async {
            guard self.enabled else { return }
            if let pid = self.helperPID(), self.isStopped(pid) { return }
            self.suspend()
        }
    }

    /// Restarts the helper so it is in a clean state, then freezes it.
    private func suspend() {
        if helperPID() == nil {
            shell("/bin/launchctl", ["kickstart", "gui/\(getuid())/\(Self.helperLabel)"])
        } else {
            shell("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/\(Self.helperLabel)"])
        }
        // The helper needs a moment to come up after the kickstart.
        var pid: pid_t?
        for _ in 0..<10 {
            if let found = helperPID() { pid = found; break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard let pid else { Log.debug("OSDUIHelper did not start, cannot hide the system bezels"); return }
        // Let the helper finish launching before it is frozen, else it never draws again later.
        Thread.sleep(forTimeInterval: 0.4)
        guard enabled else { return }
        kill(pid, SIGSTOP)
    }

    private func resume() {
        if let pid = helperPID() { kill(pid, SIGCONT) }
        shell("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/\(Self.helperLabel)"])
    }

    private func helperPID() -> pid_t? {
        let output = shell("/usr/bin/pgrep", ["-x", Self.helperName]).output
        return output.split(separator: "\n").compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }.first
    }

    /// True when `ps` reports the process in the stopped state.
    private func isStopped(_ pid: pid_t) -> Bool {
        shell("/bin/ps", ["-o", "stat=", "-p", String(pid)]).output.contains("T")
    }

    @discardableResult
    private func shell(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            return (-1, "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
