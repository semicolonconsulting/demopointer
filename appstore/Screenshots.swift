// Draws the Mac App Store screenshots (2880 x 1800, the 16:10 Retina size). The desktop, the apps being demoed and
// their numbers are made up here, so nothing real appears. The menu bar icon and the welcome window come from the
// app's own code (StatusIcon.swift, SettingsWindow.swift). They show the App Store build: the pointer stays visible
// and there's no Check for Updates.
// Run appstore/screenshots.sh after scripts/build-app.sh; it writes build/appstore-screenshots/1-*.png and so on.
import AppKit

let canvas = NSSize(width: 1440, height: 900) // points, drawn at 2x

@main
@MainActor
enum Screenshots {
    static func main() {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        // The classic icon Xcode makes from AppIcon.icon. NSWorkspace would hand back a placeholder here, since
        // macOS renders Icon Composer icons lazily.
        let appPath = CommandLine.arguments[2]
        let appIcon = NSImage(contentsOfFile: appPath + "/Contents/Resources/AppIcon.icns") ?? NSWorkspace.shared.icon(forFile: appPath)
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let dashboardWindow = NSRect(x: 520, y: 92, width: 860, height: 740)
        let pointer = NSPoint(x: 985, y: 668) // on the revenue figures in the table
        let dashboard = renderImage { drawDesktop(); drawWindow(dashboardWindow, title: "Sales Dashboard", content: drawDashboard) }
        let sheetWindow = NSRect(x: 520, y: 150, width: 860, height: 520)
        let sheetPointer = NSPoint(x: 985, y: 494) // on the bold Q3 column
        let sheet = renderImage { drawDesktop(); drawWindow(sheetWindow, title: "Q3 Forecast.numbers", content: drawSpreadsheet) }

        let shots: [(String, String, String, () -> Void)] = [
            ("1-magnify", "Hold ⌘ to magnify.", "A lens follows your pointer,\nand the rest of the screen dims.", {
                drawLensScene(dashboard, at: pointer, zoom: 2, diameter: 300, shade: 0.25)
            }),
            ("2-small-text", "Small details,\nbig and clear.", "Zoom up to 4× on numbers,\ncode or fine print.", {
                drawLensScene(sheet, at: sheetPointer, zoom: 3, diameter: 340, shade: 0.45)
            }),
            ("3-screen-share", "Your audience\nsees it too.", "The lens shows up in screen shares\nand recordings.", {
                let shared = renderImage { drawLensScene(dashboard, at: pointer, zoom: 2, diameter: 300, shade: 0.25) }
                drawDesktop()
                drawWindow(NSRect(x: 500, y: 170, width: 900, height: 560), title: "Weekly Sync", content: { drawCall($0, shared: shared) })
            }),
            ("4-welcome", "Set up\nin seconds.", "A short guide on first launch\nwalks you through permissions.", {
                drawDesktop()
                drawWelcome(appIcon: appIcon, at: NSPoint(x: 620, y: 150))
            }),
            ("5-menu", "One click away.", "Turn it on or off from the menu bar.\nRight-click for zoom, size and shade.", {
                drawDesktop()
                drawWindow(dashboardWindow, title: "Sales Dashboard", content: drawDashboard)
                drawMenu()
            }),
        ]
        for (name, title, subtitle, scene) in shots {
            let png = render {
                scene()
                drawCaption(title: title, subtitle: subtitle)
            }
            try! png.write(to: out.appendingPathComponent("\(name).png"))
            print("wrote \(name).png")
        }
    }
}

// MARK: Rendering

/// Draws into a 2x bitmap with a top-left origin and returns it as an opaque PNG, since App Store screenshots go up
/// without an alpha channel.
func render(_ body: () -> Void) -> Data {
    let image = renderCGImage(body)
    let opaque = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    opaque.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return NSBitmapImageRep(cgImage: opaque.makeImage()!).representation(using: .png, properties: [:])!
}

func renderCGImage(_ body: () -> Void) -> CGImage {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width) * 2, pixelsHigh: Int(canvas.height) * 2,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = canvas
    let previous = NSGraphicsContext.current
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.translateBy(x: 0, y: canvas.height)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    body()
    NSGraphicsContext.current = previous
    return rep.cgImage!
}

/// A full-canvas drawing as an image, to be drawn again (magnified in the lens, or shrunk into a video call).
func renderImage(_ body: () -> Void) -> NSImage {
    let image = renderCGImage(body)
    return NSImage(cgImage: image, size: canvas)
}

// MARK: Lens

/// The scene with the shade over it and the lens on top, magnifying the unshaded scene around the pointer.
func drawLensScene(_ scene: NSImage, at pointer: NSPoint, zoom: CGFloat, diameter: CGFloat, shade: CGFloat) {
    let full = NSRect(origin: .zero, size: canvas)
    scene.draw(in: full, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    NSColor.black.withAlphaComponent(shade).setFill()
    full.fill(using: .sourceOver)

    let lens = NSRect(x: pointer.x - diameter / 2, y: pointer.y - diameter / 2, width: diameter, height: diameter)
    let circle = NSBezierPath(ovalIn: lens)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 16
    shadow.shadowOffset = NSSize(width: 0, height: -6)
    shadow.set()
    NSColor.black.setFill()
    circle.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    circle.addClip()
    // The source is in the scene's own coordinates; NSImage's `from` rect has a bottom-left origin.
    let side = diameter / zoom
    let source = NSRect(x: pointer.x - side / 2, y: canvas.height - pointer.y - side / 2, width: side, height: side)
    scene.draw(in: lens, from: source, operation: .copy, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.92).setStroke()
    circle.lineWidth = 3
    circle.stroke()

    // The App Store build keeps the system pointer visible at the lens center.
    let cursor = NSCursor.arrow
    let size = NSSize(width: 26, height: 26 * cursor.image.size.height / cursor.image.size.width)
    let hotSpot = NSPoint(x: cursor.hotSpot.x * size.width / cursor.image.size.width,
                          y: cursor.hotSpot.y * size.height / cursor.image.size.height)
    cursor.image.draw(in: NSRect(x: pointer.x - hotSpot.x, y: pointer.y - hotSpot.y, width: size.width, height: size.height),
                      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

// MARK: Desktop

/// An original calm backdrop in the app's teal family, standing in for someone's wallpaper.
func drawDesktop() {
    let full = NSRect(origin: .zero, size: canvas)
    NSGradient(colors: [NSColor(srgbRed: 0.05, green: 0.20, blue: 0.27, alpha: 1),
                        NSColor(srgbRed: 0.07, green: 0.36, blue: 0.40, alpha: 1),
                        NSColor(srgbRed: 0.16, green: 0.55, blue: 0.52, alpha: 1)])!
        .draw(in: full, angle: -60)
    for (center, radius, alpha) in [(NSPoint(x: 260, y: 760), CGFloat(420), CGFloat(0.10)),
                                    (NSPoint(x: 1250, y: 120), 360, 0.08),
                                    (NSPoint(x: 700, y: 520), 260, 0.05)] {
        NSGradient(starting: NSColor.white.withAlphaComponent(alpha), ending: NSColor.white.withAlphaComponent(0))!
            .draw(in: NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                  relativeCenterPosition: .zero)
    }
    drawMenuBar()
}

func drawMenuBar(highlightIcon: Bool = false) {
    NSColor.black.withAlphaComponent(0.25).setFill()
    NSRect(x: 0, y: 0, width: canvas.width, height: 26).fill()
    var x: CGFloat = 20
    let apple = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))!
    tinted(apple, .white).draw(in: NSRect(x: x, y: 5, width: 14, height: 16))
    x += 34
    for (i, item) in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
        let text = NSAttributedString(string: item, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: i == 0 ? .bold : .regular), .foregroundColor: NSColor.white,
        ])
        text.draw(at: NSPoint(x: x, y: 5))
        x += text.size().width + 20
    }
    let clock = NSAttributedString(string: "Tue 9:41 AM", attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.white])
    clock.draw(at: NSPoint(x: canvas.width - 14 - clock.size().width, y: 5))

    let button = statusButton
    if highlightIcon {
        NSColor.white.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: button, xRadius: 5, yRadius: 5).fill()
    }
    tinted(StatusIcon.make(filled: true), .white).draw(in: NSRect(x: button.midX - 9, y: button.midY - 9, width: 18, height: 18))
}

let statusButton = NSRect(x: canvas.width - 130, y: 3, width: 28, height: 20)

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    NSImage(size: image.size, flipped: false) { rect in
        image.draw(in: rect)
        color.set()
        rect.fill(using: .sourceIn)
        return true
    }
}

// MARK: Windows

/// A light macOS window with traffic lights and a title, its content drawn by `content` in the area below the title bar.
func drawWindow(_ frame: NSRect, title: String, content: (NSRect) -> Void) {
    let titleBar: CGFloat = 34
    let shape = NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    NSColor(white: 0.985, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSColor(white: 0.95, alpha: 1).setFill()
    NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: titleBar).fill()
    for (i, color) in [NSColor(srgbRed: 1, green: 0.37, blue: 0.34, alpha: 1),
                       NSColor(srgbRed: 1, green: 0.74, blue: 0.18, alpha: 1),
                       NSColor(srgbRed: 0.16, green: 0.79, blue: 0.25, alpha: 1)].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: frame.minX + 16 + CGFloat(i) * 20, y: frame.minY + 11, width: 12, height: 12)).fill()
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor(white: 0.3, alpha: 1), .paragraphStyle: paragraph,
    ]).draw(in: NSRect(x: frame.minX, y: frame.minY + 9, width: frame.width, height: 18))
    content(NSRect(x: frame.minX, y: frame.minY + titleBar, width: frame.width, height: frame.height - titleBar))
    NSGraphicsContext.restoreGraphicsState()
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = NSColor(white: 0.15, alpha: 1),
          at point: NSPoint, align: NSTextAlignment = .left, width: CGFloat = 400, monospaced: Bool = false) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    let font = monospaced ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        .draw(in: NSRect(x: point.x, y: point.y, width: width, height: size * 1.6))
}

let accent = NSColor(srgbRed: 0.07, green: 0.62, blue: 0.62, alpha: 1)
let secondary = NSColor(white: 0.5, alpha: 1)

/// A made-up sales dashboard: a sidebar, metric cards, a line chart, a bar chart and a small table.
func drawDashboard(_ area: NSRect) {
    NSColor(white: 0.93, alpha: 1).setFill()
    NSRect(x: area.minX, y: area.minY, width: 170, height: area.height).fill()
    for (i, item) in ["Overview", "Revenue", "Customers", "Regions", "Products", "Reports", "Settings"].enumerated() {
        if i == 1 {
            accent.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: NSRect(x: area.minX + 10, y: area.minY + 18 + CGFloat(i) * 32, width: 150, height: 26), xRadius: 6, yRadius: 6).fill()
        }
        text(item, size: 13, weight: i == 1 ? .semibold : .regular, color: i == 1 ? accent : NSColor(white: 0.3, alpha: 1),
             at: NSPoint(x: area.minX + 22, y: area.minY + 22 + CGFloat(i) * 32))
    }

    let left = area.minX + 196, top = area.minY + 20
    text("Revenue · Q3", size: 22, weight: .bold, at: NSPoint(x: left, y: top))
    text("Updated 9:40 AM · All regions", size: 12, color: secondary, at: NSPoint(x: left, y: top + 32))

    let cards = [("Revenue", "$1.28M", "+12.4%"), ("New customers", "2,418", "+8.1%"), ("Avg. order", "$529", "+3.6%")]
    for (i, card) in cards.enumerated() {
        let rect = NSRect(x: left + CGFloat(i) * 214, y: top + 62, width: 200, height: 92)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
        text(card.0, size: 12, color: secondary, at: NSPoint(x: rect.minX + 14, y: rect.minY + 12))
        text(card.1, size: 26, weight: .bold, at: NSPoint(x: rect.minX + 14, y: rect.minY + 32))
        text(card.2, size: 12, weight: .semibold, color: NSColor(srgbRed: 0.1, green: 0.6, blue: 0.3, alpha: 1), at: NSPoint(x: rect.minX + 14, y: rect.minY + 66))
    }

    // Line chart.
    let chart = NSRect(x: left, y: top + 172, width: 628, height: 230)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: chart, xRadius: 10, yRadius: 10).fill()
    text("Weekly revenue", size: 13, weight: .semibold, at: NSPoint(x: chart.minX + 14, y: chart.minY + 12))
    let plot = NSRect(x: chart.minX + 44, y: chart.minY + 44, width: chart.width - 64, height: chart.height - 76)
    NSColor(white: 0.9, alpha: 1).setStroke()
    for i in 0...4 {
        let y = plot.minY + plot.height * CGFloat(i) / 4
        let line = NSBezierPath()
        line.move(to: NSPoint(x: plot.minX, y: y))
        line.line(to: NSPoint(x: plot.maxX, y: y))
        line.lineWidth = 1
        line.stroke()
        text("$\(100 - i * 25)K", size: 9, color: secondary, at: NSPoint(x: chart.minX + 8, y: y - 7), monospaced: true)
    }
    let values: [CGFloat] = [0.32, 0.38, 0.35, 0.47, 0.44, 0.52, 0.58, 0.55, 0.63, 0.70, 0.66, 0.78, 0.83]
    let line = NSBezierPath()
    var fill = NSBezierPath()
    for (i, v) in values.enumerated() {
        let p = NSPoint(x: plot.minX + plot.width * CGFloat(i) / CGFloat(values.count - 1), y: plot.maxY - plot.height * v)
        if i == 0 { line.move(to: p); fill.move(to: NSPoint(x: p.x, y: plot.maxY)); fill.line(to: p) } else { line.line(to: p); fill.line(to: p) }
    }
    fill.line(to: NSPoint(x: plot.maxX, y: plot.maxY))
    fill.close()
    accent.withAlphaComponent(0.14).setFill()
    fill.fill()
    accent.setStroke()
    line.lineWidth = 2.5
    line.lineJoinStyle = .round
    line.stroke()
    fill = NSBezierPath()
    for (i, v) in values.enumerated() where i % 3 == 0 || i == values.count - 1 {
        let p = NSPoint(x: plot.minX + plot.width * CGFloat(i) / CGFloat(values.count - 1), y: plot.maxY - plot.height * v)
        NSColor.white.setFill()
        let dot = NSBezierPath(ovalIn: NSRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        dot.fill()
        accent.setStroke()
        dot.lineWidth = 2
        dot.stroke()
    }
    for (i, week) in ["W27", "W30", "W33", "W36", "W39"].enumerated() {
        text(week, size: 9, color: secondary, at: NSPoint(x: plot.minX - 10 + plot.width * CGFloat(i) / 4, y: plot.maxY + 6), monospaced: true)
    }

    // Region table.
    let table = NSRect(x: left, y: top + 420, width: 628, height: 250)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: table, xRadius: 10, yRadius: 10).fill()
    text("Top regions", size: 13, weight: .semibold, at: NSPoint(x: table.minX + 14, y: table.minY + 12))
    let rows = [("Region", "Revenue", "Orders", "Change"),
                ("North America", "$482,310", "912", "+14.2%"), ("Europe", "$356,904", "701", "+9.8%"),
                ("Japan", "$198,775", "388", "+17.5%"), ("Asia Pacific", "$141,220", "265", "+6.3%"),
                ("Latin America", "$102,861", "152", "+4.1%")]
    for (r, row) in rows.enumerated() {
        let y = table.minY + 44 + CGFloat(r) * 32
        let header = r == 0
        let color = header ? secondary : NSColor(white: 0.2, alpha: 1)
        text(row.0, size: 12, weight: header ? .semibold : .regular, color: color, at: NSPoint(x: table.minX + 14, y: y))
        text(row.1, size: 12, weight: header ? .semibold : .regular, color: color, at: NSPoint(x: table.minX + 230, y: y), align: .right, width: 110, monospaced: true)
        text(row.2, size: 12, weight: header ? .semibold : .regular, color: color, at: NSPoint(x: table.minX + 360, y: y), align: .right, width: 80, monospaced: true)
        text(row.3, size: 12, weight: header ? .semibold : .medium,
             color: header ? secondary : NSColor(srgbRed: 0.1, green: 0.6, blue: 0.3, alpha: 1),
             at: NSPoint(x: table.minX + 470, y: y), align: .right, width: 100, monospaced: true)
        if r < rows.count - 1 {
            NSColor(white: 0.92, alpha: 1).setFill()
            NSRect(x: table.minX + 14, y: y + 24, width: table.width - 28, height: 1).fill()
        }
    }
}

/// A made-up forecast spreadsheet with small numbers.
func drawSpreadsheet(_ area: NSRect) {
    let columns = ["", "A", "B", "C", "D", "E", "F", "G", "H"]
    let header = ["", "Product", "Jul", "Aug", "Sep", "Q3", "Q4 est.", "Growth", "Owner"]
    let products = ["Starter plan", "Team plan", "Business plan", "Enterprise", "Add-on: storage", "Add-on: seats",
                    "Training", "Support", "Consulting", "Hardware", "Licenses", "Renewals", "Upgrades", "Partners",
                    "Marketplace", "Education", "Nonprofit", "Government", "Other"]
    let widths: [CGFloat] = [34, 130, 84, 84, 84, 92, 92, 70, 70]
    let rowHeight: CGFloat = 21
    NSColor(white: 0.95, alpha: 1).setFill()
    NSRect(x: area.minX, y: area.minY, width: area.width, height: 30).fill()
    text("fx   =SUM(C5:E5)", size: 11, color: NSColor(white: 0.35, alpha: 1), at: NSPoint(x: area.minX + 14, y: area.minY + 8), monospaced: true)
    let top = area.minY + 30
    var seed: UInt64 = 7
    func random() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
    for r in 0..<(products.count + 2) {
        var x = area.minX
        let y = top + CGFloat(r) * rowHeight
        if r <= 1 {
            NSColor(white: r == 0 ? 0.93 : 0.97, alpha: 1).setFill()
            NSRect(x: area.minX, y: y, width: area.width, height: rowHeight).fill()
        }
        for (c, width) in widths.enumerated() {
            let cell: String
            var weight: NSFont.Weight = .regular
            var color = NSColor(white: 0.2, alpha: 1)
            var align: NSTextAlignment = c >= 2 && c <= 7 ? .right : .left
            if r == 0 {
                cell = columns[c]; color = secondary; align = .center
            } else if r == 1 {
                cell = header[c]; weight = .semibold
            } else if c == 0 {
                cell = "\(r)"; color = secondary; align = .center
            } else {
                let p = r - 2
                switch c {
                case 1: cell = products[p]
                case 2, 3, 4: cell = String(format: "%.1f", 20 + random() * 180)
                case 5: cell = String(format: "%.1f", 120 + random() * 400); weight = .semibold
                case 6: cell = String(format: "%.1f", 140 + random() * 420)
                case 7:
                    let g = -4 + random() * 22
                    cell = String(format: "%+.1f%%", g)
                    color = g >= 0 ? NSColor(srgbRed: 0.1, green: 0.55, blue: 0.3, alpha: 1) : NSColor(srgbRed: 0.8, green: 0.2, blue: 0.2, alpha: 1)
                default: cell = ["AK", "MS", "JL", "RN", "TY"][p % 5]
                }
            }
            text(cell, size: 10.5, weight: weight, color: color, at: NSPoint(x: x + 6, y: y + 4), align: align, width: width - 12, monospaced: c >= 2)
            x += width
            NSColor(white: 0.88, alpha: 1).setFill()
            NSRect(x: x, y: y, width: 1, height: rowHeight).fill()
        }
        NSColor(white: 0.88, alpha: 1).setFill()
        NSRect(x: area.minX, y: y + rowHeight, width: area.width, height: 1).fill()
    }
    // The selected cell.
    let selected = NSRect(x: area.minX + widths[0...4].reduce(0, +), y: top + 6 * rowHeight, width: widths[5], height: rowHeight)
    accent.setStroke()
    let outline = NSBezierPath(rect: selected)
    outline.lineWidth = 2
    outline.stroke()
}

/// A made-up video call: the shared screen with the lens on it, and three participants.
func drawCall(_ area: NSRect, shared: NSImage) {
    NSColor(white: 0.12, alpha: 1).setFill()
    area.fill()
    let tileWidth: CGFloat = 170
    let stage = NSRect(x: area.minX + 16, y: area.minY + 16, width: area.width - tileWidth - 48, height: (area.width - tileWidth - 48) * 10 / 16)
    shared.draw(in: stage, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
    let label = NSRect(x: stage.minX + 10, y: stage.maxY - 34, width: 170, height: 24)
    NSColor.black.withAlphaComponent(0.55).setFill()
    NSBezierPath(roundedRect: label, xRadius: 6, yRadius: 6).fill()
    text("You are sharing your screen", size: 11, weight: .medium, color: .white, at: NSPoint(x: label.minX + 9, y: label.minY + 5))

    let people = [("AK", "Aiko", NSColor(srgbRed: 0.85, green: 0.45, blue: 0.35, alpha: 1)),
                  ("MS", "Marco", NSColor(srgbRed: 0.35, green: 0.5, blue: 0.85, alpha: 1)),
                  ("JL", "Jade", NSColor(srgbRed: 0.55, green: 0.4, blue: 0.75, alpha: 1))]
    for (i, person) in people.enumerated() {
        let tile = NSRect(x: stage.maxX + 16, y: stage.minY + CGFloat(i) * 130, width: tileWidth, height: 118)
        NSColor(white: 0.2, alpha: 1).setFill()
        NSBezierPath(roundedRect: tile, xRadius: 10, yRadius: 10).fill()
        let avatar = NSRect(x: tile.midX - 28, y: tile.minY + 18, width: 56, height: 56)
        person.2.setFill()
        NSBezierPath(ovalIn: avatar).fill()
        text(person.0, size: 20, weight: .semibold, color: .white, at: NSPoint(x: avatar.minX, y: avatar.minY + 14), align: .center, width: 56)
        text(person.1, size: 11, color: NSColor(white: 0.85, alpha: 1), at: NSPoint(x: tile.minX, y: tile.maxY - 26), align: .center, width: tileWidth)
    }

    let bar = NSRect(x: area.minX, y: area.maxY - 64, width: area.width, height: 64)
    NSColor(white: 0.08, alpha: 1).setFill()
    bar.fill()
    let buttons: [(String, NSColor)] = [("mic.fill", NSColor(white: 0.3, alpha: 1)), ("video.fill", NSColor(white: 0.3, alpha: 1)),
                                        ("rectangle.on.rectangle", accent), ("phone.down.fill", NSColor(srgbRed: 0.9, green: 0.25, blue: 0.25, alpha: 1))]
    for (i, button) in buttons.enumerated() {
        let rect = NSRect(x: bar.midX - 110 + CGFloat(i) * 60, y: bar.minY + 12, width: 40, height: 40)
        button.1.setFill()
        NSBezierPath(ovalIn: rect).fill()
        let symbol = NSImage(systemSymbolName: button.0, accessibilityDescription: nil)!.withSymbolConfiguration(.init(pointSize: 15, weight: .medium))!
        let size = symbol.size
        tinted(symbol, .white).draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
    }
}

// MARK: Welcome window and menu

/// The app's own welcome window, drawn by AppKit inside a hand-drawn window frame.
@MainActor
func drawWelcome(appIcon: NSImage, at origin: NSPoint) {
    let window = SettingsWindow().preparedWindow()
    let content = window.contentView!
    content.appearance = NSAppearance(named: .aqua)
    // The screenshot tool isn't the app, so put the app's icon in.
    func replaceIcon(in view: NSView) {
        for sub in view.subviews {
            if let imageView = sub as? NSImageView, imageView.frame.width >= 60 {
                appIcon.size = NSSize(width: 72, height: 72)
                imageView.image = appIcon
                return
            }
            replaceIcon(in: sub)
        }
    }
    replaceIcon(in: content)
    content.layoutSubtreeIfNeeded()
    let frame = NSRect(origin: origin, size: NSSize(width: content.bounds.width, height: content.bounds.height + 34))
    drawWindow(frame, title: "Welcome to Demo Pointer") { area in
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(content.bounds.width * 2), pixelsHigh: Int(content.bounds.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = content.bounds.size
        content.cacheDisplay(in: content.bounds, to: rep)
        rep.draw(in: area, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
}

/// The status item's menu, as in the App Store build, with Shade Screen open.
func drawMenu() {
    drawMenuBar(highlightIcon: true)
    let items: [(String, String, Bool, Bool)] = [ // title, shortcut, checked, submenu
        ("Settings…", "⌘,", false, false), ("-", "", false, false),
        ("Magnify While Holding ⌘", "", true, false), ("-", "", false, false),
        ("Zoom", "", false, true), ("Lens Size", "", false, true), ("Shade Screen", "", false, true), ("-", "", false, false),
        ("Open at Login", "", false, false), ("-", "", false, false),
        ("Screen Recording Settings…", "", false, false), ("Privacy Policy", "", false, false), ("-", "", false, false),
        ("Quit Demo Pointer", "⌘Q", false, false),
    ]
    let menu = drawMenuPanel(items: items, topRight: NSPoint(x: statusButton.minX + 260, y: 30), highlighted: "Shade Screen")
    let shadeY = menu.rows["Shade Screen"]!
    _ = drawMenuPanel(items: [("Off", "", false, false), ("Light", "", true, false), ("Medium", "", false, false), ("Dark", "", false, false)],
                      topRight: NSPoint(x: menu.frame.minX + 4, y: shadeY - 6), highlighted: nil)
}

func drawMenuPanel(items: [(String, String, Bool, Bool)], topRight: NSPoint, highlighted: String?) -> (frame: NSRect, rows: [String: CGFloat]) {
    let width: CGFloat = 260, rowHeight: CGFloat = 24, separator: CGFloat = 11
    let height = items.reduce(CGFloat(10)) { $0 + ($1.0 == "-" ? separator : rowHeight) }
    let frame = NSRect(x: min(topRight.x, canvas.width - 8) - width, y: topRight.y, width: width, height: height)
    let shape = NSBezierPath(roundedRect: frame, xRadius: 10, yRadius: 10)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    NSColor(white: 0.97, alpha: 0.98).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 0.8, alpha: 1).setStroke()
    shape.lineWidth = 0.5
    shape.stroke()

    var rows: [String: CGFloat] = [:]
    var y = frame.minY + 5
    for item in items {
        if item.0 == "-" {
            NSColor(white: 0.85, alpha: 1).setFill()
            NSRect(x: frame.minX + 12, y: y + 5, width: width - 24, height: 1).fill()
            y += separator
            continue
        }
        rows[item.0] = y
        let isHighlighted = item.0 == highlighted
        if isHighlighted {
            NSColor.controlAccentColor.usingColorSpace(.sRGB)!.setFill()
            NSBezierPath(roundedRect: NSRect(x: frame.minX + 5, y: y, width: width - 10, height: rowHeight), xRadius: 5, yRadius: 5).fill()
        }
        let color = isHighlighted ? NSColor.white : NSColor(white: 0.12, alpha: 1)
        if item.2 { text("✓", size: 13, weight: .semibold, color: color, at: NSPoint(x: frame.minX + 12, y: y + 3)) }
        text(item.0, size: 13, color: color, at: NSPoint(x: frame.minX + 30, y: y + 3), width: width - 80)
        if !item.1.isEmpty {
            text(item.1, size: 13, color: isHighlighted ? .white : secondary, at: NSPoint(x: frame.maxX - 70, y: y + 3), align: .right, width: 56)
        }
        if item.3 { text("›", size: 16, weight: .semibold, color: isHighlighted ? .white : secondary, at: NSPoint(x: frame.maxX - 24, y: y + 1)) }
        y += rowHeight
    }
    return (frame, rows)
}

// MARK: Caption

func drawCaption(title: String, subtitle: String) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    shadow.shadowBlurRadius = 16
    let titleText = NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 46, weight: .bold), .foregroundColor: NSColor.white, .shadow: shadow,
    ])
    let subtitleText = NSAttributedString(string: subtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.92), .shadow: shadow,
    ])
    titleText.draw(at: NSPoint(x: 70, y: 300))
    subtitleText.draw(at: NSPoint(x: 72, y: 310 + titleText.size().height + 12))
}
