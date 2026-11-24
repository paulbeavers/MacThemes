// Draws the app icon and writes Resources/AppIcon.icns.
//
//     swift tools/make-icon.swift
//
// A dark rounded square with a circle split into light and dark halves — the
// appearance switch — ringed by palette swatches in Catppuccin Mocha colours.
import AppKit
import CoreGraphics
import Foundation

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func draw(size: Int) -> CGImage {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s / 1024, y: s / 1024)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // Apple's icon grid: an 824pt rounded square centred on a 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(rgb(0x1e1e2e)); ctx.fillPath()
    ctx.restoreGState()

    // Background gradient, base to crust, with a mauve glow
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [rgb(0x313244), rgb(0x11111b)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xcba6f7, 0.35), rgb(0xcba6f7, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 512), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 512), endRadius: 430, options: [])
    ctx.restoreGState()

    let c = CGPoint(x: 512, y: 512)

    // Palette ring
    let swatches: [UInt32] = [0xf38ba8, 0xfab387, 0xf9e2af, 0xa6e3a1, 0x94e2d5, 0x89b4fa, 0xcba6f7, 0xf5c2e7]
    let ringR: CGFloat = 300, dotR: CGFloat = 46
    for (i, hex) in swatches.enumerated() {
        let a = CGFloat.pi / 2 - CGFloat(i) * 2 * .pi / CGFloat(swatches.count)
        let p = CGPoint(x: c.x + ringR * cos(a), y: c.y + ringR * sin(a))
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: rgb(0x000000, 0.4))
        ctx.setFillColor(rgb(hex))
        ctx.fillEllipse(in: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2))
        ctx.restoreGState()
    }

    // Light/dark disc, split on the diagonal
    let discR: CGFloat = 190
    let disc = CGRect(x: c.x - discR, y: c.y - discR, width: discR * 2, height: discR * 2)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: rgb(0x000000, 0.45))
    ctx.setFillColor(rgb(0xcdd6f4)); ctx.fillEllipse(in: disc)
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addEllipse(in: disc); ctx.clip()
    let light = CGGradient(colorsSpace: space, colors: [rgb(0xffffff), rgb(0xdce0e8)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(light, start: CGPoint(x: disc.minX, y: disc.maxY), end: CGPoint(x: disc.maxX, y: disc.minY), options: [])
    // Dark half: the triangle below the top-left to bottom-right diagonal
    ctx.beginPath()
    ctx.move(to: CGPoint(x: disc.maxX + 10, y: disc.maxY + 10))
    ctx.addLine(to: CGPoint(x: disc.maxX + 10, y: disc.minY - 10))
    ctx.addLine(to: CGPoint(x: disc.minX - 10, y: disc.minY - 10))
    ctx.closePath(); ctx.clip()
    let dark = CGGradient(colorsSpace: space, colors: [rgb(0x45475a), rgb(0x181825)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(dark, start: CGPoint(x: disc.midX, y: disc.midY), end: CGPoint(x: disc.maxX, y: disc.minY), options: [])
    ctx.restoreGState()

    // Thin rim
    ctx.setStrokeColor(rgb(0xffffff, 0.18)); ctx.setLineWidth(4)
    ctx.strokeEllipse(in: disc.insetBy(dx: 2, dy: 2))

    return ctx.makeImage()!
}

func writePNG(_ img: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(draw(size: base), iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(draw(size: base * 2), iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let res = root.appendingPathComponent("Resources")
try! FileManager.default.createDirectory(at: res, withIntermediateDirectories: true)
writePNG(draw(size: 1024), res.appendingPathComponent("AppIcon-1024.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", res.appendingPathComponent("AppIcon.icns").path]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote Resources/AppIcon.icns" : "iconutil failed")
