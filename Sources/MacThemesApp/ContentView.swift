import AppKit
import MacThemesCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ThemeStore
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            Sidebar(search: search)
                .navigationSplitViewColumnWidth(min: 240, ideal: 270)
        } detail: {
            if let theme = store.selectedTheme {
                ThemeDetail(theme: theme).id(theme.slug)
            } else if store.themes.isEmpty {
                EmptyState()
            } else {
                Text("Select a theme").foregroundStyle(.secondary)
            }
        }
        .searchable(text: $search, placement: .sidebar, prompt: "Filter themes")
        .toolbar {
            ToolbarItemGroup {
                Button { store.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                    .help("Reload themes from ~/.config/macthemes")
                Button { store.revealThemesFolder() } label: { Label("Themes Folder", systemImage: "folder") }
                    .help("Show the themes folder in Finder")
                Button { store.editConfig() } label: { Label("Global Config", systemImage: "gearshape") }
                    .help("Edit ~/.config/macthemes/config — settings every theme inherits")
            }
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject var store: ThemeStore
    let search: String

    var body: some View {
        let shown = store.themes.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.slug.contains(search.lowercased())
        }
        List(selection: $store.selection) {
            section("Dark", shown.filter { $0.mode != "light" })
            section("Light", shown.filter { $0.mode == "light" })
            if !store.loadErrors.isEmpty {
                Section("Couldn't load") {
                    ForEach(store.loadErrors, id: \.self) { e in
                        Label(e, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange).lineLimit(3)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ themes: [Theme]) -> some View {
        if !themes.isEmpty {
            Section(title) {
                ForEach(themes) { t in
                    ThemeRow(theme: t, active: store.activeSlug == t.slug, applying: store.applying == t.slug)
                        .tag(t.slug)
                        .contextMenu {
                            Button("Apply") { store.apply(t) }
                            Button("Edit") { store.edit(t.url) }
                            Button("Duplicate") { store.duplicate(t) }
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([t.url]) }
                        }
                }
            }
        }
    }
}

struct ThemeRow: View {
    let theme: Theme
    let active: Bool
    let applying: Bool

    var body: some View {
        HStack(spacing: 10) {
            PaletteChip(theme: theme)
            VStack(alignment: .leading, spacing: 1) {
                Text(theme.name).lineLimit(1)
                Text(theme.slug).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if applying {
                ProgressView().controlSize(.small)
            } else if active {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                    .help("Active theme")
            }
        }
        .padding(.vertical, 2)
    }
}

/// A small tile: the theme's base with its text colour and four accents.
struct PaletteChip: View {
    let theme: Theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(theme.role("base").color)
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(theme.role("text").color).frame(width: 18, height: 3)
                HStack(spacing: 2) {
                    ForEach(["mauve", "blue", "green", "red"], id: \.self) {
                        Circle().fill(theme.role($0).color).frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(width: 34, height: 26)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.12)))
    }
}

// MARK: - Empty state

struct EmptyState: View {
    @EnvironmentObject var store: ThemeStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "paintpalette").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("No themes yet").font(.title2.weight(.semibold))
            Text("Themes live in \(Paths.themesDir.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")),\none `.theme` file each — the same format as lucent's.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack {
                Button("Install Bundled Themes") { store.installBundledThemes() }
                    .buttonStyle(.borderedProminent)
                Button("Show Folder") { store.revealThemesFolder() }
            }
        }
        .padding(40)
    }
}
