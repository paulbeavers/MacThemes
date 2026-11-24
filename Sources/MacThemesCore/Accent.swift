import Foundation

/// macOS only offers eight accent colours (plus multicolour), stored as
/// `AppleAccentColor` in the global domain. A theme's accent is snapped to the
/// nearest of them; the highlight colour, which takes any RGB, keeps the exact hue.
public enum AppleAccent: String, CaseIterable {
    case multicolor, graphite, red, orange, yellow, green, blue, purple, pink

    /// The `AppleAccentColor` value; nil means delete the key (multicolour).
    public var defaultsValue: Int? {
        switch self {
        case .multicolor: return nil
        case .graphite: return -1
        case .red: return 0
        case .orange: return 1
        case .yellow: return 2
        case .green: return 3
        case .blue: return 4
        case .purple: return 5
        case .pink: return 6
        }
    }

    /// The system colour, as shown in System Settings (light appearance).
    public var swatch: RGB {
        switch self {
        case .multicolor, .blue: return RGB(hex: "007aff")!
        case .graphite: return RGB(hex: "8e8e93")!
        case .red: return RGB(hex: "ff3b30")!
        case .orange: return RGB(hex: "ff9500")!
        case .yellow: return RGB(hex: "ffcc00")!
        case .green: return RGB(hex: "28cd41")!
        case .purple: return RGB(hex: "af52de")!
        case .pink: return RGB(hex: "ff2d55")!
        }
    }

    /// The matching preset for `AppleHighlightColor`, as System Settings writes it.
    public var highlightPreset: String {
        switch self {
        case .multicolor, .blue: return "0.698039 0.843137 1.000000 Blue"
        case .graphite: return "0.847059 0.847059 0.862745 Graphite"
        case .red: return "1.000000 0.733333 0.721569 Red"
        case .orange: return "1.000000 0.874510 0.701961 Orange"
        case .yellow: return "1.000000 0.937255 0.690196 Yellow"
        case .green: return "0.752941 0.964706 0.678431 Green"
        case .purple: return "0.968627 0.831373 1.000000 Purple"
        case .pink: return "1.000000 0.749020 0.823529 Pink"
        }
    }

    /// The closest accent by hue; low-saturation colours become graphite.
    public static func nearest(to c: RGB) -> AppleAccent {
        let (h, s, l) = c.hsl
        if s < 0.18 || l < 0.08 || l > 0.95 { return .graphite }
        let hues: [(AppleAccent, Double)] = [
            (.red, 4), (.orange, 32), (.yellow, 50), (.green, 130),
            (.blue, 212), (.purple, 280), (.pink, 340),
        ]
        func dist(_ a: Double) -> Double { let d = abs(a - h).truncatingRemainder(dividingBy: 360); return min(d, 360 - d) }
        return hues.min { dist($0.1) < dist($1.1) }!.0
    }
}
