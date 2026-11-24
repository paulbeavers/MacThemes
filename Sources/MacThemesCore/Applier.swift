import AppKit
import Foundation

/// One thing a theme changes. `run` does it and returns a short result.
public struct Step: Identifiable {
    public let id = UUID()
    public let title: String
    public let detail: String
    let run: () throws -> String
}

public struct StepResult: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let ok: Bool
}

/// Turns a theme into the list of macOS settings it changes. Every key except
/// the palette is optional; an unset key leaves that setting alone.
///
///   mode             light | dark | auto
///   accent           an Apple accent name (multicolor, graphite, red, orange,
///                    yellow, green, blue, purple, pink), a palette role or a hex
///                    colour; roles and hex snap to the nearest Apple accent.
///                    Default: mauve, lucent's accent role.
///   highlight        text-selection colour: an Apple accent name, role or hex.
///                    Default: the accent, lightened.
///   wallpaper        gradient | solid | <image path> | none
///   sidebar_icons    small | medium | large
///   scrollbars       automatic | scrolling | always
///   menubar_autohide yes | no
///   dock_autohide    yes | no
///   dock_size        16–128
///   dock_magnification yes | no
///   dock_large_size  16–128
///   dock_position    left | bottom | right
///   kitty            yes | no — write the palette for kitty
///   defaults         <domain> <key> -<type> <value>, any number of times
public enum Applier {
    public static func plan(_ theme: Theme) -> [Step] {
        var steps: [Step] = []

        // Appearance
        let mode = theme.mode
        steps.append(Step(title: "Appearance", detail: mode.capitalized) {
            try Appearance.set(mode)
        })

        // Accent and highlight
        let accent = resolveAccent(theme)
        steps.append(Step(title: "Accent colour", detail: accent.apple.rawValue.capitalized
                          + (accent.exact.map { " (nearest to #\($0.hex))" } ?? "")) {
            let changed: Bool
            if let v = accent.apple.defaultsValue {
                changed = System.writeDefault("-g", "AppleAccentColor", "int", "\(v)")
            } else {
                changed = System.deleteDefault("-g", "AppleAccentColor")
            }
            return changed ? "set" : "unchanged"
        })
        let highlight = resolveHighlight(theme, accent: accent)
        steps.append(Step(title: "Highlight colour", detail: highlight.label) {
            let changed = System.writeDefault("-g", "AppleHighlightColor", "string", highlight.value)
            System.post(["AppleColorPreferencesChangedNotification", "AppleAquaColorVariantChanged"])
            return changed ? "set" : "unchanged"
        })

        // Global UI preferences
        if let v = theme["sidebar_icons"]?.lowercased(),
           let n = ["small": 1, "medium": 2, "large": 3][v] {
            steps.append(Step(title: "Sidebar icon size", detail: v.capitalized) {
                System.writeDefault("-g", "NSTableViewDefaultSizeMode", "int", "\(n)") ? "set (relaunch apps to see it)" : "unchanged"
            })
        }
        if let v = theme["scrollbars"]?.lowercased(),
           let s = ["automatic": "Automatic", "scrolling": "WhenScrolling", "always": "Always"][v] {
            steps.append(Step(title: "Scroll bars", detail: s) {
                let c = System.writeDefault("-g", "AppleShowScrollBars", "string", s)
                System.post(["AppleShowScrollBarsSettingChanged"])
                return c ? "set" : "unchanged"
            })
        }
        if let hide = theme.bool("menubar_autohide") {
            steps.append(Step(title: "Menu bar", detail: hide ? "Auto-hide" : "Always shown") {
                let c = System.writeDefault("-g", "_HIHideMenuBar", "bool", hide ? "true" : "false")
                System.post(["AppleInterfaceMenuBarHidingChangedNotification"])
                return c ? "set" : "unchanged"
            })
        }

        // Dock — one step, so it restarts at most once.
        var dock: [(String, String, String, String)] = []  // key, type, value, label
        if let b = theme.bool("dock_autohide") { dock.append(("autohide", "bool", "\(b)", b ? "auto-hide" : "always shown")) }
        if let s = theme["dock_size"], let n = Int(s) { dock.append(("tilesize", "int", "\(min(max(n, 16), 128))", "size \(n)")) }
        if let b = theme.bool("dock_magnification") { dock.append(("magnification", "bool", "\(b)", b ? "magnify" : "no magnify")) }
        if let s = theme["dock_large_size"], let n = Int(s) { dock.append(("largesize", "int", "\(min(max(n, 16), 128))", "magnified \(n)")) }
        if let p = theme["dock_position"]?.lowercased(), ["left", "bottom", "right"].contains(p) {
            dock.append(("orientation", "string", p, p))
        }
        if !dock.isEmpty {
            steps.append(Step(title: "Dock", detail: dock.map(\.3).joined(separator: ", ")) {
                var changed = false
                for (k, t, v, _) in dock where System.writeDefault("com.apple.dock", k, t, v) { changed = true }
                if changed { System.killall("Dock") }
                return changed ? "set, Dock restarted" : "unchanged"
            })
        }

        // Raw defaults
        for line in theme.defaults {
            steps.append(Step(title: "defaults", detail: line) {
                try runDefaultsLine(line)
            })
        }

        // Wallpaper
        let style = Wallpaper.style(for: theme)
        if style != .none {
            let label: String
            switch style {
            case .gradient: label = "Generated gradient"
            case .solid: label = "Solid #\(theme.role("base").hex)"
            case .file(let u): label = u.lastPathComponent
            case .none: label = ""
            }
            steps.append(Step(title: "Wallpaper", detail: label) {
                try Wallpaper.apply(theme) ?? "unchanged"
            })
        }

        // kitty
        if theme.bool("kitty") == true {
            let src = theme["terminal"].map { " (palette from \($0))" } ?? ""
            steps.append(Step(title: "kitty", detail: "~/.config/kitty/macthemes.conf" + src) {
                try Kitty.apply(theme)
                return Kitty.isIncluded ? "written, kitty reloaded"
                    : "written — add `include macthemes.conf` to kitty.conf to use it"
            })
        }
        return steps
    }

    /// Runs the plan, carrying on past failures, and records the theme as active.
    public static func apply(_ theme: Theme) -> [StepResult] {
        let results = plan(theme).map { step -> StepResult in
            do { return StepResult(title: step.title, message: try step.run(), ok: true) }
            catch { return StepResult(title: step.title, message: "\(error)", ok: false) }
        }
        Active.set(theme.slug)
        return results
    }

    // MARK: - Resolution

    public struct ResolvedAccent {
        public let apple: AppleAccent
        /// The theme's own colour when it was given as a role or hex.
        public let exact: RGB?
    }

    public static func resolveAccent(_ theme: Theme) -> ResolvedAccent {
        let spec = theme["accent"]?.lowercased() ?? "mauve"
        if let a = AppleAccent(rawValue: spec) { return ResolvedAccent(apple: a, exact: nil) }
        let c = theme.color(spec) ?? theme.role("mauve")
        return ResolvedAccent(apple: .nearest(to: c), exact: c)
    }

    public struct ResolvedHighlight {
        public let value: String   // the AppleHighlightColor string
        public let label: String
        public let color: RGB
    }

    public static func resolveHighlight(_ theme: Theme, accent: ResolvedAccent) -> ResolvedHighlight {
        if let spec = theme["highlight"]?.lowercased() {
            if let a = AppleAccent(rawValue: spec) { return preset(a) }
            if let c = theme.color(spec) { return custom(c) }
        }
        // Unset: follow the accent. The system darkens it itself in dark mode,
        // so a pastel reads well in both.
        if let exact = accent.exact { return custom(exact.mix(.white, 0.55)) }
        return preset(accent.apple)
    }

    static func preset(_ a: AppleAccent) -> ResolvedHighlight {
        let parts = a.highlightPreset.split(separator: " ")
        let c = RGB(r: Double(parts[0])!, g: Double(parts[1])!, b: Double(parts[2])!)
        return ResolvedHighlight(value: a.highlightPreset, label: String(parts[3]), color: c)
    }

    static func custom(_ c: RGB) -> ResolvedHighlight {
        let v = String(format: "%.6f %.6f %.6f Other", c.r, c.g, c.b)
        return ResolvedHighlight(value: v, label: "#\(c.hex)", color: c)
    }

    /// `<domain> <key> -<type> <value>`, where the value is the rest of the line.
    static func runDefaultsLine(_ line: String) throws -> String {
        let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true).map(String.init)
        let types = ["bool", "int", "integer", "float", "string"]
        guard parts.count == 4, parts[2].hasPrefix("-"), types.contains(String(parts[2].dropFirst())) else {
            throw ThemeError.invalid("expected: defaults = <domain> <key> -bool|-int|-float|-string <value>")
        }
        var type = String(parts[2].dropFirst())
        if type == "integer" { type = "int" }
        let changed = System.writeDefault(parts[0], parts[1], type, parts[3])
        if changed {
            switch parts[0] {
            case "com.apple.dock": System.killall("Dock"); return "set, Dock restarted"
            case "com.apple.finder": System.killall("Finder"); return "set, Finder restarted"
            default: return "set"
            }
        }
        return "unchanged"
    }
}

/// Light and dark mode go through System Events, the supported route. The
/// first use asks for permission to control System Events.
public enum Appearance {
    public static var isDark: Bool { System.readDefault("-g", "AppleInterfaceStyle") == "Dark" }
    public static var isAuto: Bool { System.readDefault("-g", "AppleInterfaceStyleSwitchesAutomatically") == "1" }

    public static func set(_ mode: String) throws -> String {
        if mode == "auto" {
            let c = System.writeDefault("-g", "AppleInterfaceStyleSwitchesAutomatically", "bool", "true")
            System.post(["AppleInterfaceThemeChangedNotification"])
            return c ? "set (may need a log out to take full effect)" : "unchanged"
        }
        let dark = mode == "dark"
        if isAuto { System.writeDefault("-g", "AppleInterfaceStyleSwitchesAutomatically", "bool", "false") }
        else if isDark == dark { return "unchanged" }
        let src = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)"
        // osascript rather than NSAppleScript, which is main-thread only.
        let r = System.run("/usr/bin/osascript", ["-e", src])
        if r.status != 0 {
            throw ThemeError.invalid("could not set appearance: \(r.err) — allow control of System Events in System Settings › Privacy & Security › Automation")
        }
        return "set"
    }
}
