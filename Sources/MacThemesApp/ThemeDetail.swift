import AppKit
import MacThemesCore
import SwiftUI

struct ThemeDetail: View {
    @EnvironmentObject var store: ThemeStore
    let theme: Theme

    var body: some View {
        let accent = Applier.resolveAccent(theme)
        let steps = Applier.plan(theme)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(accent)
                ThemePreview(theme: theme)
                if let r = store.lastResults, r.slug == theme.slug { results(r.results) }
                changes(steps)
                palette
                notes
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func header(_ accent: Applier.ResolvedAccent) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name).font(.largeTitle.weight(.semibold))
                HStack(spacing: 8) {
                    Label(theme.mode.capitalized, systemImage: theme.mode == "light" ? "sun.max" : theme.mode == "dark" ? "moon" : "circle.lefthalf.filled")
                    Text("·")
                    Text(theme.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .lineLimit(1).truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit") { store.edit(theme.url) }
            Button("Duplicate") { store.duplicate(theme) }
            Button {
                store.apply(theme)
            } label: {
                if store.applying == theme.slug {
                    ProgressView().controlSize(.small).frame(width: 90)
                } else {
                    Text(store.activeSlug == theme.slug ? "Re-apply" : "Apply Theme").frame(minWidth: 90)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(accent.apple.swatch.color)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(store.applying != nil)
        }
    }

    private func results(_ results: [StepResult]) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(results) { r in
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(r.ok ? .green : .red)
                        Text(r.title).fontWeight(.medium).frame(width: 140, alignment: .leading)
                        Text(r.message).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text("Last applied").font(.headline)
        }
    }

    private func changes(_ steps: [Step]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this theme sets").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(steps) { s in
                    GridRow {
                        Text(s.title).foregroundStyle(.secondary)
                        Text(s.detail).textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palette").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(paletteRoles, id: \.self) { role in
                    Swatch(role: role, color: theme.role(role))
                }
            }
        }
    }

    @ViewBuilder
    private var notes: some View {
        let font = theme["font"], mono = theme["mono"]
        if font != nil || mono != nil {
            Label {
                Text("macOS doesn't let apps replace the system font, so \(font.map { "“\($0)” is used for this preview" } ?? "")\(font != nil && mono != nil ? " and " : "")\(mono.map { "“\($0)” goes to kitty" } ?? "").")
            } icon: {
                Image(systemName: "textformat")
            }
            .font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct Swatch: View {
    let role: String
    let color: RGB
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("#" + color.hex, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 6).fill(color.color).frame(height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.1)))
                Text(role).font(.caption.weight(.medium))
                Text(copied ? "Copied" : "#" + color.hex).font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Copy #\(color.hex)")
    }
}
