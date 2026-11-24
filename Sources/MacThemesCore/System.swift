import AppKit
import Foundation

/// Thin wrappers over `defaults`, process launching and notifications.
public enum System {
    @discardableResult
    public static func run(_ path: String, _ args: [String]) -> (status: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do { try p.run() } catch { return (-1, "", "\(error)") }
        let o = out.fileHandleForReading.readDataToEndOfFile()
        let e = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        func s(_ d: Data) -> String { String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
        return (p.terminationStatus, s(o), s(e))
    }

    /// The current value as `defaults read` prints it, or nil if unset.
    public static func readDefault(_ domain: String, _ key: String) -> String? {
        let r = run("/usr/bin/defaults", ["read", domain, key])
        return r.status == 0 ? r.out : nil
    }

    /// Writes a value if it differs from what is there. Returns true if it changed.
    /// `type` is a defaults flag without the dash: bool, int, float, string.
    @discardableResult
    public static func writeDefault(_ domain: String, _ key: String, _ type: String, _ value: String) -> Bool {
        let before = readDefault(domain, key)
        if before == normalised(type, value) { return false }
        run("/usr/bin/defaults", ["write", domain, key, "-\(type)", value])
        return readDefault(domain, key) != before
    }

    @discardableResult
    public static func deleteDefault(_ domain: String, _ key: String) -> Bool {
        guard readDefault(domain, key) != nil else { return false }
        run("/usr/bin/defaults", ["delete", domain, key])
        return true
    }

    /// What `defaults read` would print for a value written with this type.
    static func normalised(_ type: String, _ value: String) -> String {
        switch type {
        case "bool": return ["yes", "true", "1", "on"].contains(value.lowercased()) ? "1" : "0"
        default: return value
        }
    }

    public static func post(_ names: [String]) {
        let c = DistributedNotificationCenter.default()
        for n in names {
            c.postNotificationName(.init(n), object: nil, userInfo: nil, deliverImmediately: true)
        }
    }

    public static func killall(_ process: String) {
        run("/usr/bin/killall", [process])
    }
}
