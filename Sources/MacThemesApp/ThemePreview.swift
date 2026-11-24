import AppKit
import MacThemesCore
import SwiftUI

/// What the desktop will look like: the wallpaper, a menu bar, and a window
/// drawn in macOS's own light or dark colours with the theme's accent and
/// highlight — macOS windows take those, not the full palette.
struct ThemePreview: View {
    let theme: Theme
    @Environment(\.colorScheme) private var systemScheme
    @State private var wallpaper: NSImage?

    private var dark: Bool {
        switch theme.mode {
        case "dark": return true
        case "light": return false
        default: return systemScheme == .dark
        }
    }

    var body: some View {
        let accent = Applier.resolveAccent(theme)
        let highlight = Applier.resolveHighlight(theme, accent: accent)
        // macOS draws the selection colour darker in dark mode.
        let selection = dark ? highlight.color.mix(.black, 0.55) : highlight.color
        let ui = UIColors(dark: dark)
        let previewFont = theme["font"].map { Font.custom($0, size: 12) } ?? .system(size: 12)

        ZStack(alignment: .top) {
            backdrop
            VStack(spacing: 0) {
                menuBar(ui)
                Spacer(minLength: 0)
            }
            window(ui, accent: accent.apple.swatch.color, selection: selection.color, font: previewFont)
                .padding(.top, 46)
                .padding(.horizontal, 60)
                .padding(.bottom, 54)
            VStack { Spacer(); dock(ui) }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .task(id: theme.slug + (theme["wallpaper"] ?? "")) { loadWallpaper() }
    }

    // MARK: Pieces

    @ViewBuilder
    private var backdrop: some View {
        if let wallpaper {
            GeometryReader { g in
                Image(nsImage: wallpaper).resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height).clipped()
            }
        } else {
            // No wallpaper change: show the palette's base, dimmed, as a stand-in.
            ZStack {
                theme.role("base").color
                Text("Wallpaper unchanged").font(.caption).foregroundStyle(theme.role("overlay").color)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 70)
            }
        }
    }

    private func menuBar(_ ui: UIColors) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "apple.logo")
            Text("Finder").fontWeight(.semibold)
            Text("File"); Text("Edit"); Text("View")
            Spacer()
            Image(systemName: "wifi")
            Text("Mon 9:41")
        }
        .font(.system(size: 10))
        .foregroundStyle(ui.text)
        .padding(.horizontal, 12)
        .frame(height: 20)
        .background(ui.window.opacity(0.55))
        .background(.ultraThinMaterial.opacity(0.4))
    }

    private func window(_ ui: UIColors, accent: Color, selection: Color, font: Font) -> some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    ForEach([Color.red, .yellow, .green], id: \.self) {
                        Circle().fill($0.opacity(0.85)).frame(width: 9, height: 9)
                    }
                }
                .padding(.bottom, 10)
                Text("Favourites").font(.system(size: 9, weight: .semibold)).foregroundStyle(ui.secondary)
                sidebarRow("house", "Home", ui, accent: accent, selected: true)
                sidebarRow("doc", "Documents", ui, accent: accent)
                sidebarRow("arrow.down.circle", "Downloads", ui, accent: accent)
                sidebarRow("folder", "Projects", ui, accent: accent)
                Spacer()
            }
            .padding(10)
            .frame(width: 140)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(ui.sidebar)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text(theme.name).font(font.weight(.semibold)).font(.system(size: 15))
                (Text("Selected text uses the ")
                    + Text("highlight colour").foregroundColor(ui.text)
                    + Text(", and controls use the accent."))
                    .font(font)
                    .foregroundStyle(ui.text)
                    .overlay(alignment: .topLeading) { EmptyView() }
                Text("highlight colour")
                    .font(font)
                    .padding(.horizontal, 2)
                    .background(selection, in: RoundedRectangle(cornerRadius: 2))
                    .foregroundStyle(ui.text)
                HStack(spacing: 10) {
                    Text("Apply").font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(accent, in: Capsule())
                        .foregroundStyle(.white)
                    Text("Cancel").font(.system(size: 11))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(ui.control, in: Capsule())
                        .foregroundStyle(ui.text)
                    Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden()
                        .tint(accent).controlSize(.mini).allowsHitTesting(false)
                }
                ProgressView(value: 0.62).tint(accent).frame(maxWidth: 200)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ui.window)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ui.border))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    private func sidebarRow(_ icon: String, _ label: String, _ ui: UIColors, accent: Color, selected: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(selected ? ui.text : accent).frame(width: 14)
            Text(label).foregroundStyle(ui.text)
            Spacer()
        }
        .font(.system(size: 11))
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(selected ? ui.selectedRow : .clear, in: RoundedRectangle(cornerRadius: 5))
    }

    private func dock(_ ui: UIColors) -> some View {
        HStack(spacing: 8) {
            ForEach(["folder.fill", "safari.fill", "envelope.fill", "terminal.fill", "gearshape.fill"], id: \.self) { s in
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [theme.role("blue").color, theme.role("mauve").color],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 24, height: 24)
                    .overlay(Image(systemName: s).font(.system(size: 11)).foregroundStyle(.white))
            }
        }
        .padding(6)
        .background(ui.window.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 10)
    }

    private func loadWallpaper() {
        switch Wallpaper.style(for: theme) {
        case .none:
            wallpaper = nil
        case .file(let url):
            wallpaper = NSImage(contentsOf: url)
        case let style:
            wallpaper = Wallpaper.render(theme, style: style, width: 960, height: 540)
                .map { NSImage(cgImage: $0, size: NSSize(width: 960, height: 540)) }
        }
    }
}

/// Approximations of macOS's own window colours.
private struct UIColors {
    let window, sidebar, text, secondary, control, border, selectedRow: Color

    init(dark: Bool) {
        func c(_ h: String) -> Color { RGB(hex: h)!.color }
        if dark {
            window = c("1e1e1e"); sidebar = c("2a2a2c"); text = c("ececec"); secondary = c("8e8e93")
            control = c("3a3a3c"); border = Color.white.opacity(0.12); selectedRow = Color.white.opacity(0.12)
        } else {
            window = c("ffffff"); sidebar = c("efeff1"); text = c("1d1d1f"); secondary = c("8a8a8e")
            control = c("e5e5ea"); border = Color.black.opacity(0.12); selectedRow = Color.black.opacity(0.08)
        }
    }
}
