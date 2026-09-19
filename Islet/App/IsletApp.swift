import SwiftUI

@main
struct IsletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// A template glyph of a screen edge with a notch, so the item reads as "the notch app".
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 13)
        let image = NSImage(size: size, flipped: false) { rect in
            let outer = NSBezierPath(roundedRect: NSRect(x: 0.75, y: 0.75, width: rect.width - 1.5, height: rect.height - 1.5), xRadius: 3, yRadius: 3)
            outer.lineWidth = 1.5
            NSColor.black.setStroke()
            outer.stroke()
            let notch = NSBezierPath(roundedRect: NSRect(x: rect.midX - 4, y: rect.maxY - 4.5, width: 8, height: 3.5), xRadius: 1.5, yRadius: 1.5)
            NSColor.black.setFill()
            notch.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

private struct MenuContent: View {
    var body: some View {
        Text("Islet is running · v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
        Button("Open Island") { AppDelegate.shared?.model?.open() }
            .keyboardShortcut("i", modifiers: [.control, .option])
        Divider()
        Button("Settings…") { AppDelegate.shared?.openSettings() }
            .keyboardShortcut(",")
        Button("Islet on GitHub") {
            NSWorkspace.shared.open(URL(string: "https://github.com/DevSrijit/islet")!)
        }
        Divider()
        Button("Quit Islet") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
