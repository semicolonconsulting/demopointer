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

    // White lens ring with a hand rising from the bottom edge, its index finger pointing at the
    // ring's center. Same idea as the menu bar icon (StatusIcon.swift), drawn by hand because SF
    // Symbols may not be used in app icons.
    let lensCenter = CGPoint(x: 512, y: 590)
    let lensRadius: CGFloat = 250
    let hand = handPath()

    // Ring and hand go on one layer, so the gap around the hand can be cut out of the ring.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(54)
    ctx.strokeEllipse(in: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
                                 width: lensRadius * 2, height: lensRadius * 2))
    // Gap: erase the hand's outline, widened.
    ctx.setBlendMode(.clear)
    ctx.addPath(hand)
    ctx.setLineWidth(64)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.setBlendMode(.normal)
    ctx.addPath(hand)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    // Creases between the fingers.
    ctx.setStrokeColor(NSColor(srgbRed: 0.72, green: 0.78, blue: 0.96, alpha: 1).cgColor)
    ctx.setLineWidth(12)
    ctx.setLineCap(.round)
    for (x, top, bottom) in [(CGFloat(556), CGFloat(400), CGFloat(330)), (628, 380, 310), (698, 355, 290)] {
        ctx.move(to: CGPoint(x: x, y: top))
        ctx.addLine(to: CGPoint(x: x, y: bottom))
    }
    ctx.strokePath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

/// A pointing hand seen from the back: index finger up, three folded fingers, thumb on the left,
/// and a wrist that runs off the bottom of the icon. The fingertip is at (512, 610).
func handPath() -> CGPath {
    let path = CGMutablePath()
    // Index finger.
    path.addRoundedRect(in: CGRect(x: 468, y: 330, width: 92, height: 290), cornerWidth: 46, cornerHeight: 46)
    // Folded fingers, stepping down to the right.
    path.addRoundedRect(in: CGRect(x: 552, y: 290, width: 82, height: 150), cornerWidth: 41, cornerHeight: 41)
    path.addRoundedRect(in: CGRect(x: 626, y: 270, width: 78, height: 140), cornerWidth: 39, cornerHeight: 39)
    path.addRoundedRect(in: CGRect(x: 696, y: 250, width: 70, height: 125), cornerWidth: 35, cornerHeight: 35)
    // Palm.
    path.addRoundedRect(in: CGRect(x: 440, y: 140, width: 326, height: 230), cornerWidth: 90, cornerHeight: 90)
    // Thumb, tucked against the finger.
    path.addRoundedRect(in: CGRect(x: 380, y: 230, width: 110, height: 170), cornerWidth: 55, cornerHeight: 55,
                        transform: CGAffineTransform(translationX: 435, y: 315).rotated(by: 0.5).translatedBy(x: -435, y: -315))
    // Wrist, off the bottom edge.
    path.addRect(CGRect(x: 470, y: 0, width: 260, height: 200))
    return path
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
