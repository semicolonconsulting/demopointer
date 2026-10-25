import AppKit
import QuartzCore

/// A transparent, click-through, always-on-top window that draws the circular lens.
@MainActor
final class LensWindow {
    private let window: NSWindow
    /// Space around the circle for the drop shadow.
    private let margin: CGFloat = 16
    private let shadowLayer = CALayer()
    private let imageLayer = CALayer()
    private let ringLayer = CAShapeLayer()

    private(set) var diameter: CGFloat = 0

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        window.contentView = view

        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = 0.45
        shadowLayer.shadowRadius = 8
        shadowLayer.shadowOffset = CGSize(width: 0, height: -3)

        imageLayer.masksToBounds = true
        imageLayer.backgroundColor = NSColor.black.cgColor
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear

        ringLayer.fillColor = nil
        ringLayer.strokeColor = NSColor.white.withAlphaComponent(0.9).cgColor
        ringLayer.lineWidth = 3

        view.layer?.addSublayer(shadowLayer)
        view.layer?.addSublayer(imageLayer)
        view.layer?.addSublayer(ringLayer)
    }

    func setDiameter(_ newDiameter: CGFloat) {
        guard newDiameter != diameter else { return }
        diameter = newDiameter

        let side = diameter + margin * 2
        window.setContentSize(NSSize(width: side, height: side))

        let circle = CGRect(x: margin, y: margin, width: diameter, height: diameter)
        let path = CGPath(ellipseIn: circle, transform: nil)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shadowLayer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        shadowLayer.shadowPath = path
        imageLayer.frame = circle
        imageLayer.cornerRadius = diameter / 2
        ringLayer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        ringLayer.path = path
        CATransaction.commit()
    }

    /// Centers the lens on a point in global screen coordinates.
    func center(on point: NSPoint) {
        let side = diameter + margin * 2
        window.setFrameOrigin(NSPoint(x: (point.x - side / 2).rounded(), y: (point.y - side / 2).rounded()))
    }

    func show(image: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = image
        CATransaction.commit()
        if !window.isVisible {
            window.orderFrontRegardless()
        }
    }

    func hide() {
        if window.isVisible {
            window.orderOut(nil)
        }
        imageLayer.contents = nil
    }
}
