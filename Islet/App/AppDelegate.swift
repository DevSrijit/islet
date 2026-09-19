import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    private(set) var model: NotchViewModel?
    private var panel: NotchPanel?
    private var monitors: [Any] = []
    private var hotKey: HotKey?
    private var observers: [Any] = []
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        let prefs = Preferences.shared

        installSignalHandlers()
        rebuildPanel()
        installMonitors()
        updateHotKey()

        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildPanel() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: Preferences.changedNotification, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in self?.preferencesChanged(key: note.object as? String ?? "") }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.panel?.orderFrontRegardless() }
        })

        if !prefs.hasCompletedOnboarding {
            prefs.hasCompletedOnboarding = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.openSettings() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shutDown()
    }

    /// Stops the services and hands the system bezels back. Safe to call more than once.
    private func shutDown() {
        model?.stop()
        SystemHUDSuppressor.shared.resumeForExit()
    }

    /// A `kill` or a logout sends SIGTERM, which skips `applicationWillTerminate`. The suppressed
    /// `OSDUIHelper` must be resumed on that path too, else the system bezels stay gone.
    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.shutDown()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    func openSettings() {
        SettingsWindowController.shared.show()
    }

    // MARK: Panel

    private func rebuildPanel() {
        let prefs = Preferences.shared
        guard let geometry = NotchGeometry.detect(target: prefs.displayTarget, allowSimulated: prefs.simulatedNotch) else {
            panel?.orderOut(nil)
            return
        }
        if let model {
            model.geometry = geometry
        } else {
            let model = NotchViewModel(geometry: geometry)
            self.model = model
            model.start()
        }
        guard let model else { return }
        if panel == nil {
            let panel = NotchPanel(contentRect: model.panelFrame)
            let hosting = NotchHostingView(rootView: NotchRootView(model: model))
            hosting.frame = NSRect(origin: .zero, size: model.panelSize)
            hosting.autoresizingMask = [.width, .height]
            // The panel overlaps the notch safe area; SwiftUI must not inset content for it.
            hosting.safeAreaRegions = []
            panel.contentView = hosting
            self.panel = panel
        }
        panel?.setFrame(model.panelFrame, display: true)
        panel?.contentView?.frame = NSRect(origin: .zero, size: model.panelSize)
        panel?.sharingType = prefs.hideFromScreenCapture ? .none : .readOnly
        panel?.orderFrontRegardless()
    }

    private func preferencesChanged(key: String) {
        switch key {
        case "displayTarget", "simulatedNotch": rebuildPanel()
        case "hideFromScreenCapture": panel?.sharingType = Preferences.shared.hideFromScreenCapture ? .none : .readOnly
        case "globalHotkey": updateHotKey()
        case "notchHeightOffset", "notchWidthOffset":
            // Sizes are computed from the preference, so only the panel frame needs a refresh.
            if let model {
                panel?.setFrame(model.panelFrame, display: true)
                panel?.contentView?.frame = NSRect(origin: .zero, size: model.panelSize)
            }
            model?.preferencesChanged(key: key)
        default: model?.preferencesChanged(key: key)
        }
    }

    private func updateHotKey() {
        hotKey = nil
        guard Preferences.shared.globalHotkey else { return }
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_I), modifiers: UInt32(controlKey | optionKey)) {
            Task { @MainActor in AppDelegate.shared?.model?.toggle() }
        }
    }

    // MARK: Mouse

    private func installMonitors() {
        let moved: (NSEvent) -> Void = { [weak self] _ in
            self?.model?.mouseMoved(to: NSEvent.mouseLocation)
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: moved) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { moved($0); return $0 }) { monitors.append(m) }

        // A file drag that reaches the notch opens the shelf.
        let dragged: (NSEvent) -> Void = { [weak self] _ in
            guard let model = self?.model, !model.isDropSession, model.state == .closed,
                  model.shapeScreenRect.insetBy(dx: -10, dy: -10).contains(NSEvent.mouseLocation),
                  let types = NSPasteboard(name: .drag).types, types.contains(.fileURL) else { return }
            model.dragEnteredNotch()
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: dragged) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged, handler: { dragged($0); return $0 }) { monitors.append(m) }

        let up: (NSEvent) -> Void = { [weak self] _ in
            guard let model = self?.model, model.isDropSession else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { model.dragSessionEnded() }
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: up) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp, handler: { up($0); return $0 }) { monitors.append(m) }

        if let m = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            self?.model?.scroll(deltaX: event.scrollingDeltaX,
                                deltaY: event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY,
                                phase: event.phase, momentum: event.momentumPhase)
            return event
        }) { monitors.append(m) }
    }
}
