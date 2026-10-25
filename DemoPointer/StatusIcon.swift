import AppKit

/// The menu bar icon: a lens ring with a hand pointing at its center. The ring is filled while the
/// magnifier is on and an outline while it's off. Drawn at run time as a template image, so macOS
/// tints it for light and dark menu bars.
enum StatusIcon {
    static func make(filled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            draw(in: NSRect(origin: .zero, size: size), filled: filled)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = filled ? "Demo Pointer: on" : "Demo Pointer: off"
        return image
    }

    /// Draws into an 18×18 point rect with a bottom-left origin.
    static func draw(in bounds: NSRect, filled: Bool) {
        let scale = bounds.width / 18
        let center = NSPoint(x: bounds.minX + 9 * scale, y: bounds.minY + 11 * scale)

        let ring = NSBezierPath(ovalIn: NSRect(x: center.x - 6.2 * scale, y: center.y - 6.2 * scale,
                                               width: 12.4 * scale, height: 12.4 * scale))
        if filled {
            // Grown by half the outline's width, so both versions are the same size.
            NSBezierPath(ovalIn: ring.bounds.insetBy(dx: -0.8 * scale, dy: -0.8 * scale)).fill()
        } else {
            ring.lineWidth = 1.6 * scale
            NSColor.black.setStroke()
            ring.stroke()
        }

        // The hand comes up from the bottom, its fingertip near the center.
        guard let hand = NSImage(systemSymbolName: "hand.point.up.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9.5 * scale, weight: .regular))
        else { return }
        let handSize = hand.size
        let tip = NSPoint(x: center.x, y: center.y - 0.5 * scale)
        let handRect = NSRect(x: tip.x - handSize.width * 0.39, y: tip.y - handSize.height * 0.96,
                              width: handSize.width, height: handSize.height)

        // Cut a gap around the hand so it reads separately from the ring.
        let context = NSGraphicsContext.current
        // Erasing the hand at offsets around a circle widens it evenly, so the gap has round corners.
        for step in 0..<24 {
            let angle = CGFloat(step) / 24 * 2 * .pi
            for radius in [0.55, 1.1] as [CGFloat] {
                hand.draw(in: handRect.offsetBy(dx: cos(angle) * radius * scale, dy: sin(angle) * radius * scale),
                          from: .zero, operation: .destinationOut, fraction: 1)
            }
        }
        context?.compositingOperation = .sourceOver
        hand.draw(in: handRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
