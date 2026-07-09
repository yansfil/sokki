#!/usr/bin/env swift
// Renders AppResources/AppIcon.icns: a deep-space squircle with a glowing
// waveform and a thin orbit ring — Sokki's mission-control look. Run from
// the repo root:
//   swift scripts/generate-app-icon.swift
import AppKit
import CoreGraphics

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        fatalError("no graphics context")
    }

    // Big Sur icon grid: the squircle fills ~80.4% of the canvas.
    let inset = size * 0.098
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = rect.width * 0.2237
    let squircle = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Soft drop shadow behind the squircle.
    context.saveGState()
    context.addPath(squircle)
    context.setShadow(
        offset: CGSize(width: 0, height: -size * 0.008),
        blur: size * 0.04,
        color: NSColor.black.withAlphaComponent(0.35).cgColor
    )
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(squircle)
    context.clip()

    // Deep-space base: near-black indigo falling to violet at the bottom.
    let space = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.075, green: 0.055, blue: 0.180, alpha: 1).cgColor, // #13112E
            NSColor(calibratedRed: 0.130, green: 0.075, blue: 0.320, alpha: 1).cgColor, // #211352
            NSColor(calibratedRed: 0.365, green: 0.200, blue: 0.760, alpha: 1).cgColor  // #5D33C2
        ] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        space,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.minY),
        options: []
    )

    // Violet glow pooling behind the waveform.
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.62, green: 0.44, blue: 1.0, alpha: 0.55).cgColor,
            NSColor(calibratedRed: 0.62, green: 0.44, blue: 1.0, alpha: 0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: rect.midX, y: rect.midY),
        startRadius: 0,
        endCenter: CGPoint(x: rect.midX, y: rect.midY),
        endRadius: rect.width * 0.52,
        options: []
    )

    // A few tiny stars in the upper half (invisible at 16px, alive at 512px).
    let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, a: CGFloat)] = [
        (0.20, 0.82, 0.006, 0.85), (0.32, 0.70, 0.004, 0.55),
        (0.71, 0.86, 0.005, 0.75), (0.83, 0.66, 0.004, 0.50),
        (0.57, 0.90, 0.003, 0.60), (0.13, 0.58, 0.003, 0.40)
    ]
    for star in stars {
        context.setFillColor(NSColor.white.withAlphaComponent(star.a).cgColor)
        let r = rect.width * star.r
        context.fillEllipse(in: CGRect(
            x: rect.minX + rect.width * star.x - r,
            y: rect.minY + rect.height * star.y - r,
            width: r * 2, height: r * 2
        ))
    }

    // Thin orbit ring sweeping behind the waveform.
    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY - rect.height * 0.02)
    context.rotate(by: -0.32)
    context.scaleBy(x: 1, y: 0.38)
    let orbitRadius = rect.width * 0.44
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    context.setLineWidth(rect.width * 0.012)
    context.strokeEllipse(in: CGRect(
        x: -orbitRadius, y: -orbitRadius,
        width: orbitRadius * 2, height: orbitRadius * 2
    ))
    // A small satellite dot on the ring.
    let dotRadius = rect.width * 0.030
    context.setFillColor(NSColor(calibratedRed: 0.78, green: 0.68, blue: 1.0, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(
        x: orbitRadius * cos(2.45) - dotRadius,
        y: orbitRadius * sin(2.45) - dotRadius,
        width: dotRadius * 2, height: dotRadius * 2
    ))
    context.restoreGState()

    // Waveform glyph: five rounded bars with a violet glow. Kept large so it
    // still reads at 16px in Spotlight and Finder lists.
    let barHeights: [CGFloat] = [0.22, 0.40, 0.58, 0.34, 0.18]
    let barWidth = rect.width * 0.078
    let barGap = rect.width * 0.054
    let totalWidth = barWidth * CGFloat(barHeights.count) + barGap * CGFloat(barHeights.count - 1)
    var x = rect.midX - totalWidth / 2
    context.setFillColor(NSColor.white.cgColor)
    context.setShadow(
        offset: .zero,
        blur: size * 0.028,
        color: NSColor(calibratedRed: 0.72, green: 0.55, blue: 1.0, alpha: 0.9).cgColor
    )
    for height in barHeights {
        let barHeight = rect.height * height
        let barRect = CGRect(x: x, y: rect.midY - barHeight / 2, width: barWidth, height: barHeight)
        let bar = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)
        context.addPath(bar)
        context.fillPath()
        x += barWidth + barGap
    }

    context.restoreGState()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, pixels: Int, to url: URL) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let iconsetURL = URL(fileURLWithPath: "AppResources/AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let master = drawIcon(size: 1024)
for base in [16, 32, 128, 256, 512] {
    writePNG(master, pixels: base, to: iconsetURL.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(master, pixels: base * 2, to: iconsetURL.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", "AppResources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
try? FileManager.default.removeItem(at: iconsetURL)
print("AppResources/AppIcon.icns")
