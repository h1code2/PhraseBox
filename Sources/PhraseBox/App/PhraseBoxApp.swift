import SwiftUI

@main
struct PhraseBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PhraseStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("词匣", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 880, minHeight: 560)
        }
        .commands {
            CommandMenu("短语") {
                Button("新建短语") { store.addPhrase() }
                    .keyboardShortcut("n")
                Button("复制当前短语") { store.copySelected() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Divider()
                Button("删除当前短语") { store.deleteSelected() }
                    .keyboardShortcut(.delete)
            }
        }

        MenuBarExtra("词匣", systemImage: "text.badge.plus") {
            QuickPhraseMenu(store: store) {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
