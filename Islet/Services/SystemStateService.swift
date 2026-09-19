import AppKit
import Foundation

/// Screen lock, low power mode, and full screen detection for the frontmost app.
///
/// An app counts as full screen only when the menu bar is gone. A window that merely covers the
/// screen (a terminal in its own "full screen" mode, for example) keeps the menu bar and must not
/// hide the island. The window server owns one on-screen window named "Menubar" per display while
/// the menu bar shows, so the check looks for that window.
final class SystemStateService {
    var onLockChange: ((Bool) -> Void)?
    var onLowPowerChange: ((Bool) -> Void)?
    var onFullscreenChange: ((Bool) -> Void)?

    private(set) var isLocked = false
    private(set) var isFullscreen = false

    /// The screen the island lives on, in AppKit coordinates. Nil checks every display.
    var screenFrame: CGRect? {
        didSet { if screenFrame != oldValue { scheduleCheck(after: 0) } }
    }

    static let pollInterval: TimeInterval = 2
    /// A change must hold for this long before it is reported, so the island never flickers.
    static let debounce: TimeInterval = 0.4
    /// Hiding waits a little; showing again waits longer, because the menu bar also reveals
    /// briefly in full screen when the pointer touches the top edge.
    static let hideDelay: TimeInterval = 1.0
    static let showDelay: TimeInterval = 2.5

    private let queue = DispatchQueue(label: "com.devsrijit.islet.system-state", qos: .utility)
    private var observers: [Any] = []
    private var pollTimer: Timer?
    private var pendingCheck: DispatchWorkItem?
    private var confirmation: DispatchWorkItem?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
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
                self?.scheduleCheck(after: 0.25)
            })
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.pollIfCandidateFrontmost()
        }
        pollTimer?.tolerance = 0.5
        checkFullscreen()
    }

    // MARK: Full screen

    /// Keeps checking while another app is frontmost, because a space can go full screen
    /// without any notification (for example a video player that hides the menu bar).
    private func pollIfCandidateFrontmost() {
        guard Self.frontmostIsCandidate() else { return }
        checkFullscreen()
    }

    private func scheduleCheck(after delay: TimeInterval) {
        pendingCheck?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.checkFullscreen() }
        pendingCheck = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private static func frontmostIsCandidate() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        return app.bundleIdentifier != Bundle.main.bundleIdentifier
    }

    private func checkFullscreen() {
        guard Self.frontmostIsCandidate() else { propose(false); return }
        let target = Self.windowServerRect(for: screenFrame)
        queue.async { [weak self] in
            let hidden = Self.menuBarHidden(on: target)
            DispatchQueue.main.async { self?.propose(hidden) }
        }
    }

    /// CGWindow bounds use a top-left origin on the primary screen, unlike AppKit frames.
    private static func windowServerRect(for screen: CGRect?) -> CGRect? {
        guard let screen, let primary = NSScreen.screens.first else { return nil }
        return CGRect(x: screen.minX, y: primary.frame.maxY - screen.maxY, width: screen.width, height: screen.height)
    }

    /// True when no on-screen "Menubar" window of the window server covers the top of `target`.
    /// `target` is in window server coordinates. Nil accepts a menu bar on any display.
    static func menuBarHidden(on target: CGRect?) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let menuBarLayer = Int(CGWindowLevelForKey(.mainMenuWindow))
        var sawMenuBar = false
        for info in windows {
            guard (info[kCGWindowOwnerName as String] as? String) == "Window Server",
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            let name = info[kCGWindowName as String] as? String
            let layer = info[kCGWindowLayer as String] as? Int ?? Int.min
            // Window names need Screen Recording access. Fall back to the menu bar's layer and shape.
            let isMenuBar = name == "Menubar" || (name == nil && layer == menuBarLayer && bounds.height < 60 && bounds.width > 300)
            guard isMenuBar else { continue }
            if let target {
                guard bounds.intersects(target), abs(bounds.minY - target.minY) < 2 else { continue }
            }
            sawMenuBar = true
            break
        }
        return !sawMenuBar
    }

    /// Reports a change only when it holds for the debounce interval.
    private func propose(_ full: Bool) {
        guard full != isFullscreen else { confirmation?.cancel(); confirmation = nil; return }
        guard confirmation == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.confirmation = nil
            let target = Self.windowServerRect(for: self.screenFrame)
            let candidate = Self.frontmostIsCandidate()
            self.queue.async { [weak self] in
                let hidden = candidate && Self.menuBarHidden(on: target)
                DispatchQueue.main.async { self?.update(hidden) }
            }
        }
        confirmation = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (full ? Self.hideDelay : Self.showDelay), execute: item)
    }

    private func update(_ full: Bool) {
        guard full != isFullscreen else { return }
        isFullscreen = full
        onFullscreenChange?(full)
    }
}
