import SwiftUI

@main
struct IsletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: "rectangle.topthird.inset.filled")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

private struct MenuContent: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("Islet \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
        Button("Toggle Notch") { AppDelegate.shared?.model?.toggle() }
            .keyboardShortcut("i", modifiers: [.control, .option])
        Divider()
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Islet on GitHub") {
            NSWorkspace.shared.open(URL(string: "https://github.com/DevSrijit/islet")!)
        }
        Divider()
        Button("Quit Islet") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
