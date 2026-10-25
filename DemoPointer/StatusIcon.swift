import AppKit

/// The menu bar icon: a lens ring with a hand pointing at its center. Drawn at run time as a
/// template image, so macOS tints it for light and dark menu bars.
enum StatusIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            draw(in: NSRect(origin: .zero, size: size))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Demo Pointer"
        return image
    }

    /// Draws into an 18×18 point rect with a bottom-left origin.
    static func draw(in bounds: NSRect) {
        let scale = bounds.width / 18
        let center = NSPoint(x: bounds.minX + 7 * scale, y: bounds.minY + 11 * scale)

        let ring = NSBezierPath(ovalIn: NSRect(x: center.x - 6.2 * scale, y: center.y - 6.2 * scale,
                                               width: 12.4 * scale, height: 12.4 * scale))
        ring.lineWidth = 1.6 * scale
        NSColor.black.setStroke()
        ring.stroke()

        let dotRadius = 1.3 * scale
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                    width: dotRadius * 2, height: dotRadius * 2)).fill()

        // The hand comes in from the bottom right, its fingertip just short of the center dot.
        guard let hand = NSImage(systemSymbolName: "hand.point.up.left.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9.5 * scale, weight: .regular))
        else { return }
        let handSize = hand.size
        let tip = NSPoint(x: center.x + 0.9 * scale, y: center.y - 1.3 * scale)
        let handRect = NSRect(x: tip.x - handSize.width * 0.04, y: tip.y - handSize.height * 0.96,
                              width: handSize.width, height: handSize.height)

        // Cut a gap around the hand so it reads separately from the ring.
        let context = NSGraphicsContext.current
        for dx in stride(from: -1.1, through: 1.1, by: 0.55) {
            for dy in stride(from: -1.1, through: 1.1, by: 0.55) {
                hand.draw(in: handRect.offsetBy(dx: dx * scale, dy: dy * scale), from: .zero,
                          operation: .destinationOut, fraction: 1)
            }
        }
        context?.compositingOperation = .sourceOver
        hand.draw(in: handRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
