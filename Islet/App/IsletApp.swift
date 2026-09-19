import SwiftUI

@main
struct IsletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: "macbook.gen2")
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContent: View {
    var body: some View {
        Text("Islet \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
        Button("Toggle Notch") { AppDelegate.shared?.model?.toggle() }
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
