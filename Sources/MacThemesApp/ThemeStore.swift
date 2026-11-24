import AppKit
import Foundation
import MacThemesCore
import SwiftUI

/// The themes on disk, which one is active, and applying them. Reloads by
/// itself when anything in ~/.config/macthemes changes.
@MainActor
final class ThemeStore: ObservableObject {
    @Published private(set) var themes: [Theme] = []
    @Published private(set) var loadErrors: [String] = []
    @Published private(set) var activeSlug: String?
    @Published var selection: String?
    @Published private(set) var applying: String?
    @Published private(set) var lastResults: (slug: String, results: [StepResult])?

    private var watchers: [DispatchSourceFileSystemObject] = []

    init() {
        reload()
        if selection == nil { selection = activeSlug ?? themes.first?.slug }
        watch()
    }

    var selectedTheme: Theme? { themes.first { $0.slug == selection } }
    var hasThemesFolder: Bool { FileManager.default.fileExists(atPath: Paths.themesDir.path) }

    func reload() {
        let (t, e) = Theme.loadAll()
        themes = t
        loadErrors = e
        activeSlug = Active.get()
        if let s = selection, !t.contains(where: { $0.slug == s }) { selection = t.first?.slug }
    }

    func apply(_ theme: Theme) {
        guard applying == nil else { return }
        applying = theme.slug
        Task.detached(priority: .userInitiated) {
            let results = Applier.apply(theme)
            await MainActor.run {
                self.applying = nil
                self.lastResults = (theme.slug, results)
                self.activeSlug = theme.slug
            }
        }
    }

    // MARK: - Files

    /// Copies the themes shipped in the app bundle, and the example config,
    /// into ~/.config/macthemes without overwriting anything already there.
    func installBundledThemes() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Paths.themesDir, withIntermediateDirectories: true)
        if let res = Bundle.main.resourceURL {
            let src = res.appendingPathComponent("themes")
            for f in (try? fm.contentsOfDirectory(atPath: src.path)) ?? [] where f.hasSuffix(".theme") {
                let dest = Paths.themesDir.appendingPathComponent(f)
                if !fm.fileExists(atPath: dest.path) {
                    try? fm.copyItem(at: src.appendingPathComponent(f), to: dest)
                }
            }
            let cfg = res.appendingPathComponent("config.example")
            if !fm.fileExists(atPath: Paths.configFile.path), fm.fileExists(atPath: cfg.path) {
                try? fm.copyItem(at: cfg, to: Paths.configFile)
            }
        }
        rewatch()
        reload()
        if selection == nil { selection = themes.first?.slug }
    }

    func revealThemesFolder() {
        try? FileManager.default.createDirectory(at: Paths.themesDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Paths.themesDir)
    }

    func edit(_ url: URL) {
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        // .theme has no registered app, so fall back to TextEdit.
        if NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open([url], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func editConfig() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Paths.configFile.path) {
            try? fm.createDirectory(at: Paths.configDir, withIntermediateDirectories: true)
            try? "# Settings every theme inherits; a theme's own keys win.\n".write(to: Paths.configFile, atomically: true, encoding: .utf8)
        }
        edit(Paths.configFile)
    }

    /// Duplicates a theme under a new slug and opens it for editing.
    func duplicate(_ theme: Theme) {
        let fm = FileManager.default
        var n = 2
        var dest = Paths.themesDir.appendingPathComponent("\(theme.slug)-copy.theme")
        while fm.fileExists(atPath: dest.path) {
            dest = Paths.themesDir.appendingPathComponent("\(theme.slug)-copy-\(n).theme"); n += 1
        }
        guard var text = try? String(contentsOf: theme.url, encoding: .utf8) else { return }
        let slug = String(dest.deletingPathExtension().lastPathComponent)
        text = text.replacingOccurrences(of: "name = \(theme.name)", with: "name = \(theme.name) Copy")
        try? text.write(to: dest, atomically: true, encoding: .utf8)
        reload()
        selection = slug
        edit(dest)
    }

    // MARK: - Watching

    private func watch() {
        for dir in [Paths.configDir, Paths.themesDir] {
            let fd = open(dir.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .rename, .delete, .extend], queue: .main)
            src.setEventHandler { [weak self] in
                // Editors save by writing a temp file and renaming; let it settle.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.reload() }
            }
            src.setCancelHandler { close(fd) }
            src.resume()
            watchers.append(src)
        }
    }

    private func rewatch() {
        watchers.forEach { $0.cancel() }
        watchers = []
        watch()
    }
}

extension RGB {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}
