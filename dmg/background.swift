// Draws the DMG window background: a heading, an arrow from the app to Applications, and a pointer to Read Me.
// Usage: swift dmg/background.swift <out.png> <scale>. scripts/make-dmg.sh runs it at 1x and 2x and joins
// the two into a Retina TIFF. Coordinates are Finder window points from the top left; keep the icon centers
// in sync with scripts/make-dmg.sh.
import AppKit

let size = NSSize(width: 640, height: 520) // a little taller than the window, so shorter title bars show no edge
let iconSize: CGFloat = 112
let app = NSPoint(x: 170, y: 192)
let applications = NSPoint(x: 470, y: 192)
let readMe = NSPoint(x: 470, y: 348)

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let scale = CGFloat(Double(CommandLine.arguments[2])!)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
cg.translateBy(x: 0, y: size.height)
cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

// Finder draws icon labels black in Light Mode and white in Dark Mode, whatever the picture is.
// A mid-tone indigo keeps both readable.
NSGradient(starting: NSColor(srgbRed: 0.42, green: 0.42, blue: 0.70, alpha: 1),
           ending: NSColor(srgbRed: 0.34, green: 0.40, blue: 0.64, alpha: 1))!
    .draw(in: NSRect(origin: .zero, size: size), angle: 90)

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1,
          in rect: NSRect, align: NSTextAlignment = .center) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        .paragraphStyle: paragraph,
    ]).draw(in: rect)
}

text("Drag Demo Pointer to Applications", size: 22, weight: .semibold,
     in: NSRect(x: 0, y: 38, width: size.width, height: 30))
text("Then open it from your Applications folder.", size: 13, weight: .regular, alpha: 0.85,
     in: NSRect(x: 0, y: 74, width: size.width, height: 18))

// Arrow from the app to Applications.
let start = app.x + iconSize / 2 + 22, end = applications.x - iconSize / 2 - 22
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: start, y: app.y))
arrow.line(to: NSPoint(x: end, y: app.y))
arrow.move(to: NSPoint(x: end - 14, y: app.y - 13))
arrow.line(to: NSPoint(x: end, y: app.y))
arrow.line(to: NSPoint(x: end - 14, y: app.y + 13))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor.white.withAlphaComponent(0.9).setStroke()
arrow.stroke()

// Divider, then a note pointing at Read Me.
NSColor.white.withAlphaComponent(0.25).setFill()
NSRect(x: 60, y: 282, width: size.width - 120, height: 1).fill()
let noteRight = readMe.x - iconSize / 2 - 16
text("First time? Allow Screen Recording", size: 13, weight: .semibold,
     in: NSRect(x: 30, y: readMe.y - 20, width: noteRight - 30, height: 18), align: .right)
text("Read Me walks you through it.", size: 13, weight: .regular, alpha: 0.85,
     in: NSRect(x: 30, y: readMe.y + 1, width: noteRight - 30, height: 18), align: .right)

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: out)
