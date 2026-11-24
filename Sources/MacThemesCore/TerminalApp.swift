import AppKit
import Foundation

/// With `terminal_app = yes`, each theme gets a Terminal.app profile named
/// "MacThemes – <name>", which becomes the default and replaces the profile
/// on open tabs that were using the previous default.
///
/// The profile starts as a copy of your current default profile, so font,
/// window size, shell and transparency carry over; only the colours change,
/// plus the font when the theme sets `mono`, and the background opacity when
/// it sets `terminal_alpha`.
///
/// Terminal's scripting can switch profiles but not create them. When
/// Terminal is running, a new or changed profile is loaded by opening it as a
/// .terminal file — which briefly opens a window that is closed again. When
/// Terminal is not running, the profile goes straight into its preferences.
public enum TerminalApp {
    static let domain = "com.apple.Terminal" as CFString
    static let prefix = "MacThemes – "
    static let baseKey = "__base profile"

    public static func profileName(_ theme: Theme) -> String { prefix + theme.name }

    public static func apply(_ theme: Theme) throws -> String {
        let name = profileName(theme)
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal").isEmpty

        let profiles = CFPreferencesCopyAppValue("Window Settings" as CFString, domain) as? [String: Any] ?? [:]
        let previous = running ? (try? script("name of default settings")) ?? defaultName() : defaultName()
        // The profile you used before MacThemes is the base for every theme,
        // so one theme's opacity or font doesn't leak into the next.
        if let previous, !previous.hasPrefix(prefix), Hashes.get(baseKey) == nil {
            Hashes.set(baseKey, previous)
        }
        let baseName = Hashes.get(baseKey).flatMap { profiles[$0] != nil ? $0 : nil } ?? previous ?? ""
        let base = profiles[baseName] as? [String: Any]
            ?? profiles.first(where: { $0.key.hasPrefix(prefix) })?.value as? [String: Any]
            ?? [:]
        let profile = try build(theme, name: name, base: base)
        let hash = String(fnv(profile), radix: 16)

        guard running else {
            var all = profiles
            all[name] = profile
            CFPreferencesSetAppValue("Window Settings" as CFString, all as CFDictionary, domain)
            CFPreferencesSetAppValue("Default Window Settings" as CFString, name as CFString, domain)
            CFPreferencesSetAppValue("Startup Window Settings" as CFString, name as CFString, domain)
            CFPreferencesAppSynchronize(domain)
            Hashes.set(name, hash)
            return "profile set as default for the next launch"
        }

        let known = try script("get name of every settings set").components(separatedBy: ", ")
        var loaded = false
        if !known.contains(name) || Hashes.get(name) != hash {
            if known.contains(name) { _ = try? script("delete settings set \(quote(name))") }
            try importProfile(profile, name: name)
            Hashes.set(name, hash)
            loaded = true
        }

        // Retarget tabs on the old default, or on any MacThemes profile.
        var match = "name of current settings of t starts with \(quote(prefix))"
        if let previous { match += " or name of current settings of t is \(quote(previous))" }
        try script("""
            set s to settings set \(quote(name))
            set default settings to s
            set startup settings to s
            repeat with w in windows
                try
                    repeat with t in tabs of w
                        if \(match) then set current settings of t to s
                    end repeat
                end try
            end repeat
            """)
        return loaded ? "profile loaded and applied" : "profile applied"
    }

    // MARK: - Profile

    static func build(_ theme: Theme, name: String, base: [String: Any]) throws -> [String: Any] {
        let pal = try TerminalPalette(theme)
        var p = base
        p["name"] = name
        p["type"] = "Window Settings"
        p["ProfileCurrentVersion"] = p["ProfileCurrentVersion"] ?? 2.09
        p["DynamicANSIForegroundColors"] = false

        // Keep the base profile's opacity unless the theme sets one.
        var alpha = 1.0
        if let data = base["BackgroundColor"] as? Data, let c = unarchive(data, NSColor.self) {
            alpha = Double(c.alphaComponent)
        }
        if let a = theme["terminal_alpha"].flatMap(Double.init) { alpha = a }

        p["BackgroundColor"] = try archive(pal.background, alpha: alpha)
        p["TextColor"] = try archive(pal.foreground)
        p["TextBoldColor"] = try archive(pal.foreground)
        p["CursorColor"] = try archive(pal.cursor)
        p["SelectionColor"] = try archive(pal.selection, alpha: 0.45)
        let names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
        for (i, c) in pal.ansi.enumerated() {
            p["ANSI\(i >= 8 ? "Bright" : "")\(names[i % 8])Color"] = try archive(c)
        }

        if let mono = theme["mono"], !mono.isEmpty {
            var size: CGFloat = 13
            if let data = base["Font"] as? Data, let f = unarchive(data, NSFont.self) { size = f.pointSize }
            if let font = NSFont(name: mono, size: size) ?? NSFontManager.shared.font(
                withFamily: mono, traits: [], weight: 5, size: size) {
                p["Font"] = try NSKeyedArchiver.archivedData(withRootObject: font, requiringSecureCoding: false)
            }
        }
        return p
    }

    static func archive(_ c: RGB, alpha: Double = 1) throws -> Data {
        let color = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: alpha)
        return try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
    }

    static func unarchive<T: NSObject & NSSecureCoding>(_ data: Data, _ type: T.Type) -> T? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: type, from: data)
    }

    /// Opens the profile as a .terminal file, waits for Terminal to know it,
    /// then closes the window that opening it created.
    static func importProfile(_ profile: [String: Any], name: String) throws {
        let dir = Paths.cacheDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(name).terminal")
        let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
        try data.write(to: file)

        let before = Set(try script("get id of every window").components(separatedBy: ", "))
        System.run("/usr/bin/open", ["-g", "-a", "Terminal", file.path])
        var ok = false
        for _ in 0..<40 {
            Thread.sleep(forTimeInterval: 0.1)
            if (try? script("exists settings set \(quote(name))")) == "true" { ok = true; break }
        }
        guard ok else { throw ThemeError.invalid("Terminal did not load the profile from \(file.path)") }
        Thread.sleep(forTimeInterval: 0.3)
        let after = (try? script("get id of every window").components(separatedBy: ", ")) ?? []
        for id in after where !before.contains(id) && Int(id) != nil {
            _ = try? script("close (every window whose id is \(id)) saving no")
        }
    }

    static func defaultName() -> String? {
        CFPreferencesCopyAppValue("Default Window Settings" as CFString, domain) as? String
    }

    @discardableResult
    static func script(_ body: String) throws -> String {
        let r = System.run("/usr/bin/osascript", ["-e", "tell application \"Terminal\"\n\(body)\nend tell"])
        guard r.status == 0 else {
            let denied = r.err.contains("-1743")
            throw ThemeError.invalid("Terminal: \(r.err)" + (denied
                ? " — allow MacThemes to control Terminal in System Settings › Privacy & Security › Automation" : ""))
        }
        return r.out
    }

    static func quote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Stable across runs: Swift dictionaries iterate in a random order.
    static func fnv(_ profile: [String: Any]) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        func feed<S: Sequence>(_ bytes: S) where S.Element == UInt8 { for b in bytes { h = (h ^ UInt64(b)) &* 0x100000001b3 } }
        for k in profile.keys.sorted() {
            feed(k.utf8)
            if let d = profile[k] as? Data { feed(d) } else { feed("\(profile[k]!)".utf8) }
        }
        return h
    }

    /// Which version of each profile Terminal has loaded, so an unchanged
    /// theme is not re-imported.
    enum Hashes {
        static var url: URL { Paths.cacheDir.appendingPathComponent("terminal-profiles.plist") }
        static func all() -> [String: String] {
            (try? Data(contentsOf: url)).flatMap {
                try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: String]
            } ?? [:]
        }
        static func get(_ name: String) -> String? { all()[name] }
        static func set(_ name: String, _ hash: String) {
            var a = all(); a[name] = hash
            try? FileManager.default.createDirectory(at: Paths.cacheDir, withIntermediateDirectories: true)
            if let d = try? PropertyListSerialization.data(fromPropertyList: a, format: .xml, options: 0) {
                try? d.write(to: url)
            }
        }
    }
}
