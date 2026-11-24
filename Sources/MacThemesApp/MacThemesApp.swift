import AppKit
import MacThemesCore
import SwiftUI

@main
struct MacThemesApp: App {
    @StateObject private var store = ThemeStore()
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("MacThemes", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 860, minHeight: 560)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Reload Themes") { store.reload() }
                    .keyboardShortcut("r")
                Button("Show Themes Folder") { store.revealThemesFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Edit Global Config") { store.editConfig() }
            }
        }

        MenuBarExtra("MacThemes", systemImage: "paintpalette") {
            MenuBarContent().environmentObject(store)
        }
    }
}

/// When launched as a bare binary (swift run) rather than from the .app,
/// there is no Info.plist to make it a regular app; do it here.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Closing the window leaves the menu bar item running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: ThemeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let dark = store.themes.filter { $0.mode != "light" }
        let light = store.themes.filter { $0.mode == "light" }
        Section("Dark") { ForEach(dark) { item($0) } }
        Section("Light") { ForEach(light) { item($0) } }
        Divider()
        Button("Open MacThemes…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Reload Themes") { store.reload() }
        Divider()
        Button("Quit MacThemes") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    private func item(_ t: Theme) -> some View {
        Toggle(t.name, isOn: Binding(
            get: { store.activeSlug == t.slug },
            set: { _ in store.apply(t) }))
    }
}
