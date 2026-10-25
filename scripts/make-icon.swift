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

    // Teal background, the same gradient as desktopcloth's icon: blue-teal at the top to green-teal at the bottom.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let colors = [
        NSColor(srgbRed: 0.25, green: 0.72, blue: 0.81, alpha: 1).cgColor,
        NSColor(srgbRed: 0.11, green: 0.78, blue: 0.68, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: [])
    ctx.restoreGState()

    // A dark teal lens with a white rim, and an old-style engraved pointing hand (a manicule) with
    // a shirt cuff, its index finger pointing up. Drawn by hand: SF Symbols may not be used in app icons.
    let lensCenter = CGPoint(x: 512, y: 560)
    let lensRadius: CGFloat = 300
    let lens = CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.setFillColor(NSColor(srgbRed: 0.06, green: 0.40, blue: 0.42, alpha: 1).cgColor)
    ctx.fillEllipse(in: lens)
    ctx.restoreGState()
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(22)
    ctx.strokeEllipse(in: lens.insetBy(dx: 11, dy: 11))

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    // The hand is laid out on a canvas with a top-left origin.
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 20, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    drawManicule(in: ctx)
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

/// Draws the pointing hand on a 1024 canvas with a top-left origin: ink outlines on white, with
/// engraving-style hatching on the shaded right side.
func drawManicule(in ctx: CGContext) {
    let ink = NSColor(srgbRed: 0.10, green: 0.12, blue: 0.13, alpha: 1).cgColor
    let paper = NSColor(srgbRed: 1, green: 0.99, blue: 0.96, alpha: 1).cgColor

    func shape(_ path: CGPath, hatch: CGRect? = nil, line: CGFloat = 11) {
        ctx.addPath(path)
        ctx.setFillColor(paper)
        ctx.fillPath()
        if let hatch {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setStrokeColor(ink)
            ctx.setLineWidth(5)
            ctx.setLineCap(.round)
            var x = hatch.minX
            while x < hatch.maxX {
                ctx.move(to: CGPoint(x: x, y: hatch.minY))
                ctx.addLine(to: CGPoint(x: x - 40, y: hatch.maxY))
                x += 16
            }
            ctx.strokePath()
            ctx.restoreGState()
        }
        ctx.addPath(path)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(line)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }

    // The shapes below are laid out around (540, 530); the finger sits inside the lens and the cuff overlaps its rim.
    ctx.translateBy(x: 512, y: 530)
    ctx.scaleBy(x: 1.08, y: 1.08)
    ctx.translateBy(x: -540, y: -530)

    func rounded(_ rect: CGRect, _ radius: CGFloat, rotation: CGFloat = 0) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotation).translatedBy(x: -center.x, y: -center.y)
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: &transform)
    }

    // Back of the hand and wrist, behind everything else.
    shape(rounded(CGRect(x: 438, y: 470, width: 200, height: 260), 70), hatch: CGRect(x: 590, y: 470, width: 70, height: 260))
    // Index finger, pointing up.
    shape(rounded(CGRect(x: 462, y: 236, width: 78, height: 300), 39), hatch: CGRect(x: 528, y: 300, width: 30, height: 240))
    // Fingernail and knuckle creases.
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(6)
    ctx.addPath(rounded(CGRect(x: 484, y: 252, width: 34, height: 52), 17))
    ctx.move(to: CGPoint(x: 478, y: 378)); ctx.addQuadCurve(to: CGPoint(x: 524, y: 378), control: CGPoint(x: 501, y: 390))
    ctx.move(to: CGPoint(x: 480, y: 398)); ctx.addQuadCurve(to: CGPoint(x: 522, y: 398), control: CGPoint(x: 501, y: 408))
    ctx.strokePath()
    // Three curled fingers, stacked down the right.
    shape(rounded(CGRect(x: 520, y: 470, width: 140, height: 72), 36), hatch: CGRect(x: 620, y: 470, width: 60, height: 72))
    shape(rounded(CGRect(x: 520, y: 536, width: 146, height: 72), 36), hatch: CGRect(x: 626, y: 536, width: 60, height: 72))
    shape(rounded(CGRect(x: 516, y: 602, width: 136, height: 70), 35), hatch: CGRect(x: 612, y: 602, width: 60, height: 70))
    // Thumb, folded across the curled fingers.
    shape(rounded(CGRect(x: 412, y: 540, width: 190, height: 70), 35, rotation: -0.35))
    // Shirt cuff with a button.
    let cuff = CGMutablePath()
    cuff.move(to: CGPoint(x: 434, y: 706))
    cuff.addLine(to: CGPoint(x: 650, y: 706))
    cuff.addLine(to: CGPoint(x: 660, y: 822))
    cuff.addLine(to: CGPoint(x: 424, y: 822))
    cuff.closeSubpath()
    shape(cuff, hatch: CGRect(x: 618, y: 706, width: 60, height: 116))
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(6)
    ctx.move(to: CGPoint(x: 432, y: 734)); ctx.addLine(to: CGPoint(x: 652, y: 734))
    ctx.move(to: CGPoint(x: 427, y: 796)); ctx.addLine(to: CGPoint(x: 657, y: 796))
    ctx.strokePath()
    ctx.setFillColor(paper)
    ctx.fillEllipse(in: CGRect(x: 582, y: 748, width: 32, height: 32))
    ctx.strokeEllipse(in: CGRect(x: 582, y: 748, width: 32, height: 32))
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
