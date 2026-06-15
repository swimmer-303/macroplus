#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

// Renders the MacroPlus app icon into an .iconset folder of PNGs.
// Design: squircle gradient background + white click cursor + click ripples + "+" badge.

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "MacroPlus.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

/// Approximate Apple "squircle" rounded rect path.
func squirclePath(in rect: CGRect, radiusFraction: CGFloat = 0.2237) -> CGPath {
    let r = rect.width * radiusFraction
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func drawIcon(size: CGFloat) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    let full = CGRect(x: 0, y: 0, width: size, height: size)
    // Slight inset so the squircle isn't clipped at edges.
    let inset = size * 0.045
    let rect = full.insetBy(dx: inset, dy: inset)

    // --- Background gradient (clipped to squircle) ---
    ctx.saveGState()
    ctx.addPath(squirclePath(in: rect))
    ctx.clip()

    let grad = CGGradient(colorsSpace: cs, colors: [
        color(0.42, 0.50, 1.00),   // top  – indigo
        color(0.66, 0.40, 1.00)    // bot  – violet
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY),
                           options: [])

    // Soft top highlight glow.
    let glow = CGGradient(colorsSpace: cs, colors: [
        color(1, 1, 1, 0.28), color(1, 1, 1, 0)
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow,
                           startCenter: CGPoint(x: rect.midX, y: rect.maxY * 0.92), startRadius: 0,
                           endCenter: CGPoint(x: rect.midX, y: rect.maxY * 0.92), endRadius: rect.width * 0.7,
                           options: [])
    ctx.restoreGState()

    // Helper to scale design coords (0..1 within rect) to context points.
    func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + fx * rect.width, y: rect.minY + fy * rect.height)
    }
    let u = rect.width   // unit for line widths

    // --- Click ripple rings, emanating from cursor tip ---
    let tip = p(0.40, 0.66)
    ctx.setLineCap(.round)
    let ripples: [(CGFloat, CGFloat)] = [(0.16, 0.9), (0.235, 0.55), (0.31, 0.3)]
    for (radF, alpha) in ripples {
        ctx.setStrokeColor(color(1, 1, 1, Double(alpha)))
        ctx.setLineWidth(u * 0.022)
        let rr = u * radF
        // Arc on the upper-right facing away from the pointer body.
        ctx.addArc(center: tip, radius: rr,
                   startAngle: -.pi * 0.32, endAngle: .pi * 0.30, clockwise: false)
        ctx.strokePath()
    }

    // --- Cursor (classic arrow pointer) in white with soft shadow ---
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
                  blur: size * 0.03, color: color(0, 0, 0, 0.30))

    // Arrow points, designed in a local 0..1 box then mapped.
    let arrow: [(CGFloat, CGFloat)] = [
        (0.40, 0.66),   // tip
        (0.40, 0.30),   // bottom-left of head
        (0.485, 0.385),
        (0.545, 0.305),
        (0.595, 0.345),
        (0.535, 0.425),
        (0.625, 0.46)
    ]
    let path = CGMutablePath()
    path.move(to: p(arrow[0].0, arrow[0].1))
    for pt in arrow.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
    path.closeSubpath()

    ctx.addPath(path)
    ctx.setFillColor(color(1, 1, 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Thin indigo outline on the cursor for crispness.
    ctx.addPath(path)
    ctx.setStrokeColor(color(0.30, 0.34, 0.78, 0.9))
    ctx.setLineJoin(.round)
    ctx.setLineWidth(u * 0.012)
    ctx.strokePath()

    // --- "+" badge bottom-right ---
    let badgeC = p(0.70, 0.30)
    let badgeR = u * 0.135
    ctx.setFillColor(color(1, 1, 1))
    ctx.fillEllipse(in: CGRect(x: badgeC.x - badgeR, y: badgeC.y - badgeR,
                               width: badgeR * 2, height: badgeR * 2))
    // plus sign
    ctx.setStrokeColor(color(0.55, 0.40, 1.0))
    ctx.setLineCap(.round)
    ctx.setLineWidth(u * 0.032)
    let arm = badgeR * 0.55
    ctx.move(to: CGPoint(x: badgeC.x - arm, y: badgeC.y))
    ctx.addLine(to: CGPoint(x: badgeC.x + arm, y: badgeC.y))
    ctx.move(to: CGPoint(x: badgeC.x, y: badgeC.y - arm))
    ctx.addLine(to: CGPoint(x: badgeC.x, y: badgeC.y + arm))
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// Required iconset members: base size + @2x.
let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for (px, name) in specs {
    let img = drawIcon(size: CGFloat(px))
    writePNG(img, to: "\(outDir)/\(name)")
    print("rendered \(name) (\(px)px)")
}
print("done → \(outDir)")
