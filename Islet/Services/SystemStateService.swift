import AppKit
import Foundation

/// Screen lock, low power mode, and full screen detection for the frontmost app.
final class SystemStateService {
    var onLockChange: ((Bool) -> Void)?
    var onLowPowerChange: ((Bool) -> Void)?
    var onFullscreenChange: ((Bool) -> Void)?

    private(set) var isLocked = false
    private(set) var isFullscreen = false
    private var observers: [Any] = []

    func start() {
        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.isLocked = true
            self?.onLockChange?(true)
        })
        observers.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.isLocked = false
            self?.onLockChange?(false)
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.onLowPowerChange?(ProcessInfo.processInfo.isLowPowerModeEnabled)
        })
        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(wnc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // The window list updates a beat after the space switch finishes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self?.checkFullscreen() }
            })
        }
        checkFullscreen()
    }

    /// True when the frontmost app has a window that covers a whole screen.
    private func checkFullscreen() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              app.bundleIdentifier != "com.apple.finder",
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            update(false); return
        }
        let pid = app.processIdentifier
        let screens = NSScreen.screens.map { screen -> CGRect in
            // CGWindow bounds use a top-left origin on the primary screen.
            guard let primary = NSScreen.screens.first else { return screen.frame }
            return CGRect(x: screen.frame.minX, y: primary.frame.maxY - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
        }
        let full = windows.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { return false }
            return screens.contains { abs($0.width - bounds.width) < 2 && abs($0.height - bounds.height) < 2 && abs($0.minX - bounds.minX) < 2 }
        }
        update(full)
    }

    private func update(_ full: Bool) {
        guard full != isFullscreen else { return }
        isFullscreen = full
        onFullscreenChange?(full)
    }
}
