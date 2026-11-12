#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outputURL: URL = {
    if CommandLine.arguments.count > 1 {
        return URL(fileURLWithPath: CommandLine.arguments[1])
    }
    return URL(fileURLWithPath: "Resources/AppIcon.icns")
}()

func renderIcon(size: Int) -> Data? {
    let dim = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.current = context
    let cg = context.cgContext

    let inset = dim * 0.088
    let rect = CGRect(x: inset, y: inset, width: dim - inset * 2, height: dim - inset * 2)
    let radius = rect.width * 0.225
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Deep obsidian base (#070709 -> #12101A)
    squircle.addClip()
    let bgColors = [
        NSColor(calibratedRed: 0.09, green: 0.07, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.025, green: 0.025, blue: 0.035, alpha: 1.0).cgColor
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let grad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(
            grad,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    // Subtle oil-light glow in top-left & bottom-right
    cg.saveGState()
    let purpleGlow = [
        NSColor(calibratedRed: 0.66, green: 0.41, blue: 0.94, alpha: 0.45).cgColor,
        NSColor(calibratedRed: 0.66, green: 0.41, blue: 0.94, alpha: 0.0).cgColor
    ] as CFArray
    if let pGrad = CGGradient(colorsSpace: colorSpace, colors: purpleGlow, locations: [0.0, 1.0]) {
        cg.drawRadialGradient(
            pGrad,
            startCenter: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.22),
            startRadius: 0,
            endCenter: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.22),
            endRadius: rect.width * 0.62,
            options: []
        )
    }

    let cyanGlow = [
        NSColor(calibratedRed: 0.23, green: 0.78, blue: 0.86, alpha: 0.28).cgColor,
        NSColor(calibratedRed: 0.23, green: 0.78, blue: 0.86, alpha: 0.0).cgColor
    ] as CFArray
    if let cGrad = CGGradient(colorsSpace: colorSpace, colors: cyanGlow, locations: [0.0, 1.0]) {
        cg.drawRadialGradient(
            cGrad,
            startCenter: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.2),
            startRadius: 0,
            endCenter: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.2),
            endRadius: rect.width * 0.58,
            options: []
        )
    }
    cg.restoreGState()

    // Editorial serif italic "it" + purple period "."
    let fontSize = rect.width * 0.50
    let italicFont = NSFont(name: "Georgia-Italic", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let dotFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)

    let word = NSMutableAttributedString(
        string: "it",
        attributes: [
            .font: italicFont,
            .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1.0),
            .kern: -fontSize * 0.05
        ]
    )
    word.append(
        NSAttributedString(
            string: ".",
            attributes: [
                .font: dotFont,
                .foregroundColor: NSColor(calibratedRed: 0.68, green: 0.43, blue: 0.95, alpha: 1.0)
            ]
        )
    )

    let textSize = word.size()
    let textOrigin = NSPoint(
        x: rect.midX - textSize.width / 2 + rect.width * 0.015,
        y: rect.midY - textSize.height / 2 - rect.height * 0.02
    )
    word.draw(at: textOrigin)

    // Subtle sparkle star in top-right corner
    let starCenter = CGPoint(x: rect.maxX - rect.width * 0.23, y: rect.maxY - rect.height * 0.24)
    let rOuter = rect.width * 0.068
    let rInner = rOuter * 0.26
    let starPath = NSBezierPath()
    for i in 0..<8 {
        let angle = CGFloat(i) * (.pi / 4.0)
        let r = (i % 2 == 0) ? rOuter : rInner
        let pt = CGPoint(x: starCenter.x + cos(angle) * r, y: starCenter.y + sin(angle) * r)
        if i == 0 { starPath.move(to: pt) } else { starPath.line(to: pt) }
    }
    starPath.close()
    NSColor(calibratedRed: 0.78, green: 0.58, blue: 0.98, alpha: 0.95).setFill()
    starPath.fill()

    // Inner glass border
    let borderPath = NSBezierPath(roundedRect: rect.insetBy(dx: dim * 0.006, dy: dim * 0.006), xRadius: radius, yRadius: radius)
    borderPath.lineWidth = max(1.0, dim * 0.012)
    NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
    borderPath.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

let fm = FileManager.default
let tempIconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("itww-\(UUID().uuidString).iconset")
try fm.createDirectory(at: tempIconset, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: tempIconset) }

let specs: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in specs {
    guard let png = renderIcon(size: spec.pixels) else {
        fputs("Failed rendering \(spec.name)\n", stderr)
        exit(1)
    }
    try png.write(to: tempIconset.appendingPathComponent(spec.name))
}

try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", tempIconset.path, "-o", outputURL.path]
try proc.run()
proc.waitUntilExit()
guard proc.terminationStatus == 0 else {
    fputs("iconutil failed with code \(proc.terminationStatus)\n", stderr)
    exit(proc.terminationStatus)
}
print("Generated \(outputURL.path)")
