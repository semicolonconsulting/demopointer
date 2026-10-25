// Makes the app icon from art/icon-source.png (a 1254 px render of the glossy teal squircle with the
// ring and pointing hand on a white background) and writes every size into the AppIcon asset catalog.
// It cuts the squircle out along its traced edge, so the glass rim stays whole and the soft glow and
// white background around it are dropped, then places it on Apple's icon grid (an 824 pt wide body on a
// 1024 canvas) with a drop shadow.
// Usage: swift scripts/make-icon.swift
import AppKit

let outputDir = URL(fileURLWithPath: "DemoPointer/Assets.xcassets/AppIcon.appiconset")
/// Luminance between the pale glow outside the squircle (about 0.9) and its rim (about 0.5).
let edgeThreshold: CGFloat = 0.7
/// How far inside the traced edge the cut goes, in source pixels, so no glow fringe is left.
let edgeInset: CGFloat = 0.6

let source = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "art/icon-source.png")))!.cgImage!

/// Luminance of every source pixel, row 0 at the top.
let luminance: [[CGFloat]] = {
    let width = source.width, height = source.height
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    return (0..<height).map { y in
        (0..<width).map { x in
            let i = (y * width + x) * 4
            return (0.3 * CGFloat(p[i]) + 0.59 * CGFloat(p[i + 1]) + 0.11 * CGFloat(p[i + 2])) / 255
        }
    }
}()

/// Scans from outside inward along one line of luminance values and returns where it first crosses
/// the threshold, as a sub-pixel position measured from the scan's start, or nil if it never does.
func edge(_ values: [CGFloat]) -> CGFloat? {
    for i in 1..<values.count where values[i] < edgeThreshold && values[i - 1] >= edgeThreshold {
        let t = (values[i - 1] - edgeThreshold) / (values[i - 1] - values[i])
        return CGFloat(i - 1) + t + 0.5
    }
    return nil
}

/// The cut-out mask: each pixel's coverage inside the traced edge, both across its row and down its
/// column, so straight sides and corners are all anti-aliased.
let mask: CGImage = {
    let width = source.width, height = source.height
    var rows = [(CGFloat, CGFloat)?](repeating: nil, count: height)
    for y in 0..<height {
        let line = luminance[y]
        // Only lines that cross the squircle: its middle stays dark all the way.
        guard let left = edge(line), let fromRight = edge(line.reversed()) else { continue }
        rows[y] = (left + edgeInset, CGFloat(width) - fromRight - edgeInset)
    }
    var columns = [(CGFloat, CGFloat)?](repeating: nil, count: width)
    for x in 0..<width {
        let line = (0..<height).map { luminance[$0][x] }
        guard let top = edge(line), let fromBottom = edge(line.reversed()) else { continue }
        columns[x] = (top + edgeInset, CGFloat(height) - fromBottom - edgeInset)
    }
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let out = ctx.data!.assumingMemoryBound(to: UInt8.self)
    func coverage(_ center: CGFloat, _ span: (CGFloat, CGFloat)?) -> CGFloat {
        guard let (start, end) = span, end > start else { return 0 }
        return min(max(center - start + 0.5, 0), 1) * min(max(end - center + 0.5, 0), 1)
    }
    for y in 0..<height {
        for x in 0..<width {
            let c = min(coverage(CGFloat(x) + 0.5, rows[y]), coverage(CGFloat(y) + 0.5, columns[x]))
            out[y * width + x] = UInt8(c * 255)
        }
    }
    return ctx.makeImage()!
}()

/// The squircle's bounds in the source, from the mask.
let sourceBody: CGRect = {
    let width = source.width, height = source.height
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    var minX = width, maxX = 0, minY = height, maxY = 0
    for y in 0..<height { for x in 0..<width where p[y * width + x] > 127 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}()

/// Draws the 1024×1024 master. Coordinates have a top-left origin.
func drawIcon(in ctx: CGContext) {
    // 824 pt wide like every macOS icon body, centered.
    let scale = 824 / sourceBody.width
    let body = CGRect(x: 100, y: 512 - sourceBody.height * scale / 2, width: 824, height: sourceBody.height * scale)
    let imageRect = CGRect(x: body.minX - sourceBody.minX * scale, y: body.minY - sourceBody.minY * scale,
                           width: CGFloat(source.width) * scale, height: CGFloat(source.height) * scale)

    ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    // CGImages draw bottom-up, so flip locally on this top-left canvas.
    ctx.saveGState()
    ctx.translateBy(x: imageRect.minX, y: imageRect.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.clip(to: CGRect(origin: .zero, size: imageRect.size), mask: mask)
    ctx.draw(source, in: CGRect(origin: .zero, size: imageRect.size))
    ctx.restoreGState()
    ctx.endTransparencyLayer()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    let cg = ctx.cgContext
    // Top-left origin, 1024 units across.
    cg.translateBy(x: 0, y: CGFloat(pixels))
    cg.scaleBy(x: CGFloat(pixels) / 1024, y: -CGFloat(pixels) / 1024)
    drawIcon(in: cg)
    return rep.representation(using: .png, properties: [:])!
}

print("Squircle in the source: \(sourceBody)")
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
