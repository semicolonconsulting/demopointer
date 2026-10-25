// Draws the app icon and writes every size into the AppIcon asset catalog.
// Usage: swift scripts/make-icon.swift
import AppKit

let outputDir = URL(fileURLWithPath: "DemoPointer/Assets.xcassets/AppIcon.appiconset")

/// Draws the 1024×1024 master on the macOS icon grid (824pt body, 100pt margin).
func drawIcon(in ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the body.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(bodyPath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Indigo-to-blue background.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let colors = [
        NSColor(srgbRed: 0.36, green: 0.30, blue: 0.95, alpha: 1).cgColor,
        NSColor(srgbRed: 0.10, green: 0.55, blue: 1.00, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])
    ctx.restoreGState()

    let lensCenter = CGPoint(x: 460, y: 565)
    let lensRadius: CGFloat = 235

    // Handle, pointing down-right.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(78)
    ctx.setStrokeColor(NSColor.white.cgColor)
    let angle = -CGFloat.pi / 4
    let handleStart = CGPoint(x: lensCenter.x + cos(angle) * (lensRadius + 20), y: lensCenter.y + sin(angle) * (lensRadius + 20))
    let handleEnd = CGPoint(x: lensCenter.x + cos(angle) * (lensRadius + 175), y: lensCenter.y + sin(angle) * (lensRadius + 175))
    ctx.move(to: handleStart)
    ctx.addLine(to: handleEnd)
    ctx.strokePath()
    ctx.restoreGState()

    // Glass.
    let lensRect = CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.setFillColor(NSColor(srgbRed: 0.93, green: 0.94, blue: 0.98, alpha: 1).cgColor)
    ctx.fillEllipse(in: lensRect)
    ctx.restoreGState()

    // Magnified pointer arrow inside the glass.
    ctx.saveGState()
    ctx.addEllipse(in: lensRect)
    ctx.clip()
    let arrow: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -16), CGPoint(x: 4, y: -12),
        CGPoint(x: 6.5, y: -17.5), CGPoint(x: 9, y: -16.5), CGPoint(x: 6.5, y: -11), CGPoint(x: 11.5, y: -11),
    ]
    let scale: CGFloat = 17
    let origin = CGPoint(x: lensCenter.x - 5.5 * scale, y: lensCenter.y + 9 * scale)
    let arrowPath = CGMutablePath()
    arrowPath.addLines(between: arrow.map { CGPoint(x: origin.x + $0.x * scale, y: origin.y + $0.y * scale) })
    arrowPath.closeSubpath()
    ctx.addPath(arrowPath)
    ctx.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(18)
    ctx.setLineJoin(.round)
    ctx.drawPath(using: .fillStroke)
    ctx.restoreGState()

    // Rim.
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(46)
    ctx.strokeEllipse(in: lensRect.insetBy(dx: -23, dy: -23))
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    let cg = ctx.cgContext
    cg.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: cg)
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: pixels).write(to: outputDir.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDir.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icon images to \(outputDir.path)")
