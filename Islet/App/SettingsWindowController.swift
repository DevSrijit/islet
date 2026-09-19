import AppKit
import SwiftUI

/// Owns the one Settings window.
///
/// Islet is an accessory app, so SwiftUI's `Settings` scene and `openSettings` do not work from the
/// menu bar extra or from the notch panel. This controller hosts `SettingsView` in a plain `NSWindow`
/// and activates the app before it shows the window.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private static let frameName = "IsletSettingsWindow"
    private static let defaultSize = NSSize(width: 820, height: 640)
    private static let minimumSize = NSSize(width: 760, height: 600)

    private var hasShown = false

    private init() {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.defaultSize),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Islet Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.minSize = Self.minimumSize
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenNone]
        window.tabbingMode = .disallowed
        window.identifier = NSUserInterfaceItemIdentifier(Self.frameName)

        let hosting = NSHostingView(rootView: SettingsView())
        // Let the split view own the toolbar and the window title, as a SwiftUI scene would.
        hosting.sceneBridgingOptions = [.toolbars, .title]
        window.contentView = hosting
        window.setFrameAutosaveName(Self.frameName)

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SettingsWindowController does not support NSCoder.")
    }

    /// Shows the window and brings the app to the front, even though the app is `.accessory`.
    func show() {
        guard let window else { return }
        if !hasShown {
            hasShown = true
            if !window.setFrameUsingName(Self.frameName) {
                window.center()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // Fall back to an empty toolbar so the unified title bar keeps its height when SwiftUI adds none.
        DispatchQueue.main.async { [weak window] in
            guard let window, window.toolbar == nil else { return }
            let toolbar = NSToolbar(identifier: "IsletSettingsToolbar")
            toolbar.showsBaselineSeparator = false
            window.toolbar = toolbar
        }
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: Self.frameName)
    }
}
