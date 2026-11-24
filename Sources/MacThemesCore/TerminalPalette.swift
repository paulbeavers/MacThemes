import Foundation

/// The terminal colours a theme renders to, shared by kitty and Terminal.app.
/// Follows lucent's foot mapping: `terminal = <slug>` borrows another theme's
/// palette, and a light palette swaps ANSI black and white.
public struct TerminalPalette {
    public let source: Theme
    public let foreground, background, cursor, selection: RGB
    /// ANSI 0–15.
    public let ansi: [RGB]

    public init(_ theme: Theme) throws {
        var p = theme
        if let other = theme["terminal"], !other.isEmpty, other != theme.slug {
            p = try Theme.load(other)
        }
        source = p
        foreground = p.role("text")
        background = p.role("base")
        cursor = p.role("rosewater")
        selection = p.role("rosewater")
        let light = p.mode == "light"
        let black = light ? ("subtext", "overlay") : ("surface1", "overlay")
        let white = light ? ("surface1", "surface0") : ("subtext", "text")
        let hues = ["red", "green", "yellow", "blue", "pink", "teal"].map { p.role($0) }
        ansi = [p.role(black.0)] + hues + [p.role(white.0)]
            + [p.role(black.1)] + hues + [p.role(white.1)]
    }
}
