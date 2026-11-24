import Foundation

/// The colour roles a lucent theme defines, darkest background to brightest accent.
public let paletteRoles = [
    "crust", "mantle", "base", "surface0", "surface1", "overlay", "subtext", "text",
    "rosewater", "red", "peach", "yellow", "green", "teal", "sapphire", "blue",
    "lavender", "mauve", "pink",
]

public enum ThemeError: Error, CustomStringConvertible {
    case notFound(String)
    case invalid(String)

    public var description: String {
        switch self {
        case .notFound(let s): return "no theme named '\(s)' (see: macthemes list)"
        case .invalid(let s): return s
        }
    }
}

/// Where everything lives. Honours XDG_CONFIG_HOME, and MACTHEMES_DIR overrides it outright.
public enum Paths {
    public static var configDir: URL {
        let env = ProcessInfo.processInfo.environment
        if let d = env["MACTHEMES_DIR"], !d.isEmpty { return URL(fileURLWithPath: d) }
        let xdg = env["XDG_CONFIG_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            ?? (NSHomeDirectory() + "/.config")
        return URL(fileURLWithPath: xdg).appendingPathComponent("macthemes")
    }
    public static var themesDir: URL { configDir.appendingPathComponent("themes") }
    public static var configFile: URL { configDir.appendingPathComponent("config") }
    public static var activeFile: URL { configDir.appendingPathComponent(".active-theme") }
    public static var cacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("macthemes")
    }
}

/// A parsed `key = value` file: a lucent .theme, or the global config.
///
/// Lines starting with `#` are comments. Keys may repeat only for `defaults`,
/// which collects every occurrence in order; for any other key the last wins.
public struct KeyValueFile {
    public var values: [String: String] = [:]
    public var defaults: [String] = []

    public init() {}

    public init(url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        for (n, raw) in text.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else {
                throw ThemeError.invalid("\(url.path):\(n + 1): expected key = value")
            }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            var value = String(line[line.index(after: eq)...])
            // A trailing comment needs whitespace before its #, so `#1e1e2e` stays a value.
            if let r = value.range(of: #"\s+#.*$"#, options: .regularExpression) { value.removeSubrange(r) }
            value = value.trimmingCharacters(in: .whitespaces)
            if key == "defaults" { defaults.append(value) } else { values[key] = value }
        }
    }
}

public struct Theme: Identifiable {
    public var id: String { slug }
    public let slug: String
    public let url: URL
    /// Global config underneath, the theme's own keys on top.
    public let values: [String: String]
    public let defaults: [String]

    public var name: String { values["name"] ?? slug }
    public var mode: String { values["mode"]?.lowercased() ?? "dark" }

    public subscript(key: String) -> String? { values[key] }

    /// A role name, or a hex colour.
    public func color(_ spec: String?) -> RGB? {
        guard let spec = spec?.trimmingCharacters(in: .whitespaces), !spec.isEmpty else { return nil }
        if paletteRoles.contains(spec.lowercased()), let v = values[spec.lowercased()] {
            return RGB(hex: v)
        }
        return RGB(hex: spec)
    }

    public func role(_ name: String) -> RGB {
        color(name) ?? RGB(hex: "808080")!
    }

    /// True for yes/true/on/1, false for no/false/off/0, nil if unset.
    public func bool(_ key: String) -> Bool? {
        guard let v = values[key]?.lowercased() else { return nil }
        switch v {
        case "yes", "true", "on", "1": return true
        case "no", "false", "off", "0": return false
        default: return nil
        }
    }

    public static func load(_ slug: String) throws -> Theme {
        let url = Paths.themesDir.appendingPathComponent("\(slug).theme")
        guard FileManager.default.fileExists(atPath: url.path) else { throw ThemeError.notFound(slug) }
        let own = try KeyValueFile(url: url)
        let global = FileManager.default.fileExists(atPath: Paths.configFile.path)
            ? try KeyValueFile(url: Paths.configFile) : KeyValueFile()
        let merged = global.values.merging(own.values) { _, theme in theme }
        let theme = Theme(slug: slug, url: url, values: merged, defaults: global.defaults + own.defaults)
        try theme.validate()
        return theme
    }

    public static func all() -> [Theme] { loadAll().themes }

    /// Every theme in the themes folder, plus a message for each file that failed to load.
    public static func loadAll() -> (themes: [Theme], errors: [String]) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: Paths.themesDir.path) else { return ([], []) }
        var themes: [Theme] = [], errors: [String] = []
        for f in files.filter({ $0.hasSuffix(".theme") }).sorted() {
            do { themes.append(try Theme.load(String(f.dropLast(".theme".count)))) }
            catch { errors.append("\(error)") }
        }
        return (themes, errors)
    }

    public func validate() throws {
        let missing = paletteRoles.filter { values[$0].flatMap(RGB.init(hex:)) == nil }
        if !missing.isEmpty {
            throw ThemeError.invalid("\(url.path): missing or bad colour for \(missing.joined(separator: ", "))")
        }
        if !["light", "dark", "auto"].contains(mode) {
            throw ThemeError.invalid("\(url.path): mode must be light, dark or auto")
        }
    }
}

public enum Active {
    public static func get() -> String? {
        (try? String(contentsOf: Paths.activeFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func set(_ slug: String) {
        try? (slug + "\n").write(to: Paths.activeFile, atomically: true, encoding: .utf8)
    }
}
