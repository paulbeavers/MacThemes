import AppKit
import Foundation
import MacThemesCore

let usage = """
usage: macthemes list                 themes, * marks the active one
       macthemes current              the active theme's slug
       macthemes show <theme>         what applying it would change
       macthemes apply <theme>        apply it
       macthemes wallpaper <theme> <out.png> [WxH]
                                      render its generated wallpaper to a file

Themes are ~/.config/macthemes/themes/<slug>.theme; ~/.config/macthemes/config
holds defaults every theme inherits.
"""

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
let cmd = args.isEmpty ? "list" : args.removeFirst()

do {
    switch cmd {
    case "list":
        let (themes, errors) = Theme.loadAll()
        let active = Active.get()
        for t in themes {
            print("\(t.slug == active ? "*" : " ") \(t.slug.padding(toLength: 32, withPad: " ", startingAt: 0)) \(t.name) (\(t.mode))")
        }
        errors.forEach { FileHandle.standardError.write("warning: \($0)\n".data(using: .utf8)!) }
        if themes.isEmpty { print("no themes in \(Paths.themesDir.path)") }
    case "current":
        print(Active.get() ?? "")
    case "show":
        guard let slug = args.first else { fail(usage) }
        let t = try Theme.load(slug)
        print("\(t.name) — \(t.url.path)")
        for s in Applier.plan(t) { print("  \(s.title.padding(toLength: 18, withPad: " ", startingAt: 0)) \(s.detail)") }
    case "apply":
        guard let slug = args.first else { fail(usage) }
        let t = try Theme.load(slug)
        var failed = false
        for r in Applier.apply(t) {
            print("\(r.ok ? "✓" : "✗") \(r.title): \(r.message)")
            failed = failed || !r.ok
        }
        exit(failed ? 1 : 0)
    case "wallpaper":
        guard args.count >= 2 else { fail(usage) }
        let t = try Theme.load(args[0])
        var w = 3840, h = 2160
        if args.count > 2 {
            let p = args[2].split(separator: "x").compactMap { Int($0) }
            guard p.count == 2 else { fail("size must be WxH") }
            (w, h) = (p[0], p[1])
        }
        var style = Wallpaper.style(for: t)
        if style == .none { style = .gradient }
        guard let src = try Wallpaper.file(t, style: style, width: w, height: h) else {
            fail("\(t.slug) uses an image wallpaper, not a generated one")
        }
        let out = URL(fileURLWithPath: args[1])
        try? FileManager.default.removeItem(at: out)
        try FileManager.default.copyItem(at: src, to: out)
        print(out.path)
    case "-h", "--help", "help":
        print(usage)
    default:
        fail(usage)
    }
} catch {
    fail("macthemes: \(error)")
}
