import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A theme's `wallpaper` is one of:
///
///   gradient       generated from the palette: base into crust, with a soft glow
///                  of the accent and blue in opposite corners
///   solid          a flat fill of base
///   <path>         an image; relative paths resolve against the themes folder
///   none           leave the wallpaper alone (the default)
public enum Wallpaper {
    public enum Style: Equatable { case none, gradient, solid, file(URL) }

    public static func style(for theme: Theme) -> Style {
        guard let v = theme["wallpaper"], !v.isEmpty else { return .none }
        switch v.lowercased() {
        case "none", "off", "no": return .none
        case "gradient": return .gradient
        case "solid": return .solid
        default:
            let path = (v as NSString).expandingTildeInPath
            let url = path.hasPrefix("/") ? URL(fileURLWithPath: path)
                : Paths.themesDir.appendingPathComponent(path)
            return .file(url)
        }
    }

    /// Draws a generated wallpaper. Returns nil for styles that are not generated.
    public static func render(_ theme: Theme, style: Style, width: Int, height: Int) -> CGImage? {
        guard style == .gradient || style == .solid,
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        func cg(_ c: RGB, _ a: Double = 1) -> CGColor { CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: a) }
        let base = theme.role("base"), crust = theme.role("crust")
        let w = CGFloat(width), h = CGFloat(height)

        if style == .solid {
            ctx.setFillColor(cg(base))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            return ctx.makeImage()
        }

        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let light = theme.mode == "light"
        // Light themes fade towards their lightest surface rather than crust,
        // which in some light palettes is darker than base.
        let far = light ? theme.role("mantle").mix(base, 0.3) : crust
        let linear = CGGradient(colorsSpace: space, colors: [cg(base), cg(far)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(linear, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])

        let accent = theme.color(theme["accent"]) ?? theme.role("mauve")
        let glows: [(RGB, CGPoint, Double)] = [
            (accent, CGPoint(x: w * 0.85, y: h * 0.12), light ? 0.16 : 0.22),
            (theme.role("blue"), CGPoint(x: w * 0.1, y: h * 0.95), light ? 0.10 : 0.14),
        ]
        let radius = max(w, h) * 0.75
        for (c, p, a) in glows {
            let g = CGGradient(colorsSpace: space, colors: [cg(c, a), cg(c, 0)] as CFArray, locations: [0, 1])!
            ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: radius, options: [])
        }
        return ctx.makeImage()
    }

    /// A cached PNG of the generated wallpaper at this size. The name carries a
    /// hash of the palette, since macOS caches wallpapers by path.
    public static func file(_ theme: Theme, style: Style, width: Int, height: Int) throws -> URL? {
        guard style == .gradient || style == .solid else { return nil }
        let key = paletteRoles.map { theme[$0] ?? "" }.joined() + (theme["accent"] ?? "") + theme.mode + "\(style)"
        let hash = String(fnv1a(key), radix: 16)
        let dir = Paths.cacheDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(theme.slug)-\(hash)-\(width)x\(height).png")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        guard let img = render(theme, style: style, width: width, height: height),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw ThemeError.invalid("could not render wallpaper") }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { throw ThemeError.invalid("could not write \(url.path)") }
        return url
    }

    /// Sets the wallpaper on every screen. macOS applies it to each screen's current Space.
    public static func apply(_ theme: Theme) throws -> String? {
        let style = style(for: theme)
        if style == .none { return nil }
        let fill = theme.role("base")
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
            .fillColor: NSColor(srgbRed: fill.r, green: fill.g, blue: fill.b, alpha: 1),
        ]
        var used = Set<String>()
        for screen in NSScreen.screens {
            let url: URL
            if case .file(let f) = style {
                guard FileManager.default.fileExists(atPath: f.path) else {
                    throw ThemeError.invalid("wallpaper not found: \(f.path)")
                }
                url = f
            } else {
                let scale = screen.backingScaleFactor
                url = try file(theme, style: style,
                               width: Int(screen.frame.width * scale), height: Int(screen.frame.height * scale))!
            }
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
            used.insert(url.lastPathComponent)
        }
        return used.sorted().joined(separator: ", ")
    }

    static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }
}
