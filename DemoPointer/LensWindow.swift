import AppKit
import QuartzCore

/// A transparent, click-through, always-on-top window that draws the circular lens.
@MainActor
final class LensWindow {
    private let window: NSWindow
    /// Space around the circle for the drop shadow.
    private let margin: CGFloat = 24
    private let shadowLayer = CALayer()
    private let imageLayer = CALayer()

    // Liquid Glass style rim, drawn over the magnified image.
    /// Width of the glass band just inside the edge.
    private let bandWidth: CGFloat = 9
    /// The same image, zoomed a little more and shown only in the band, so the edge looks refracted.
    private let refractionLayer = CALayer()
    private let refractionMask = CAShapeLayer()
    /// Soft frosted tint and inner shading across the band.
    private let bandLayer = CAGradientLayer()
    private let bandMask = CAShapeLayer()
    /// Faint rainbow fringe along the inside of the rim.
    private let fringeLayer = CAGradientLayer()
    private let fringeMask = CAShapeLayer()
    /// Bright specular arcs, strongest top-left with a softer bounce bottom-right.
    private let specularLayer = CAGradientLayer()
    private let specularMask = CAShapeLayer()
    /// Thin translucent outer rim.
    private let rimLayer = CAShapeLayer()

    private let fadeDuration: TimeInterval = 0.15
    private var isShown = false

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
        shadowLayer.shadowOpacity = 0.35
        shadowLayer.shadowRadius = 14
        shadowLayer.shadowOffset = CGSize(width: 0, height: -6)

        imageLayer.masksToBounds = true
        imageLayer.backgroundColor = NSColor.black.cgColor
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear

        refractionLayer.masksToBounds = true
        refractionLayer.contentsGravity = .resize
        refractionLayer.magnificationFilter = .linear
        refractionMask.fillRule = .evenOdd
        refractionLayer.mask = refractionMask

        // Lighter towards the top, slightly darker towards the bottom, like light passing through glass.
        bandLayer.colors = [
            NSColor.white.withAlphaComponent(0.30).cgColor,
            NSColor.white.withAlphaComponent(0.06).cgColor,
            NSColor.black.withAlphaComponent(0.12).cgColor,
        ]
        bandLayer.locations = [0, 0.5, 1]
        bandLayer.startPoint = CGPoint(x: 0.5, y: 1)
        bandLayer.endPoint = CGPoint(x: 0.5, y: 0)
        bandMask.fillRule = .evenOdd
        bandLayer.mask = bandMask

        fringeLayer.type = .conic
        fringeLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        fringeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        fringeLayer.colors = [
            NSColor(srgbRed: 0.20, green: 0.75, blue: 1.00, alpha: 0.55),
            NSColor(srgbRed: 0.45, green: 0.35, blue: 1.00, alpha: 0.10),
            NSColor(srgbRed: 1.00, green: 0.25, blue: 0.70, alpha: 0.55),
            NSColor(srgbRed: 1.00, green: 0.60, blue: 0.20, alpha: 0.10),
            NSColor(srgbRed: 0.30, green: 1.00, blue: 0.55, alpha: 0.40),
            NSColor(srgbRed: 0.20, green: 0.75, blue: 1.00, alpha: 0.55),
        ].map(\.cgColor)
        fringeMask.fillColor = nil
        fringeMask.strokeColor = NSColor.white.cgColor
        fringeMask.lineWidth = 2
        fringeLayer.mask = fringeMask

        // Diagonal: bright top-left, clear through the middle, a softer glint bottom-right.
        specularLayer.colors = [
            NSColor.white.withAlphaComponent(1.0).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
            NSColor.white.withAlphaComponent(0.6).cgColor,
        ]
        specularLayer.locations = [0.05, 0.42, 0.62, 0.95]
        specularLayer.startPoint = CGPoint(x: 0.15, y: 0.85)
        specularLayer.endPoint = CGPoint(x: 0.85, y: 0.15)
        specularMask.fillColor = nil
        specularMask.strokeColor = NSColor.white.cgColor
        specularMask.lineWidth = 2.5
        specularLayer.mask = specularMask

        rimLayer.fillColor = nil
        rimLayer.strokeColor = NSColor.white.withAlphaComponent(0.55).cgColor
        rimLayer.lineWidth = 1

        for layer in [shadowLayer, imageLayer, refractionLayer, bandLayer, fringeLayer, specularLayer, rimLayer] {
            view.layer?.addSublayer(layer)
        }
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

        // Paths below are in each layer's own coordinates, where the circle fills the bounds.
        let local = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        let band = CGMutablePath()
        band.addEllipse(in: local)
        band.addEllipse(in: local.insetBy(dx: bandWidth, dy: bandWidth))

        // The refraction copy is zoomed about 6% more, then clipped back to the band.
        let zoom = diameter * 0.06
        refractionLayer.frame = circle.insetBy(dx: -zoom / 2, dy: -zoom / 2)
        refractionLayer.cornerRadius = refractionLayer.frame.width / 2
        refractionMask.frame = refractionLayer.bounds
        let refractionBand = CGMutablePath()
        let inLayer = local.offsetBy(dx: zoom / 2, dy: zoom / 2)
        refractionBand.addEllipse(in: inLayer)
        refractionBand.addEllipse(in: inLayer.insetBy(dx: bandWidth, dy: bandWidth))
        refractionMask.path = refractionBand

        for layer in [bandLayer, fringeLayer, specularLayer] {
            layer.frame = circle
        }
        bandMask.frame = local
        bandMask.path = band
        fringeMask.frame = local
        fringeMask.path = CGPath(ellipseIn: local.insetBy(dx: 2.5, dy: 2.5), transform: nil)
        specularMask.frame = local
        specularMask.path = CGPath(ellipseIn: local.insetBy(dx: 1.5, dy: 1.5), transform: nil)

        rimLayer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        rimLayer.path = CGPath(ellipseIn: circle.insetBy(dx: 0.5, dy: 0.5), transform: nil)
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
        refractionLayer.contents = image
        CATransaction.commit()

        guard !isShown else { return }
        isShown = true
        if !window.isVisible {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        fade(to: 1)
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        fade(to: 0)
        Task { @MainActor [weak self, fadeDuration] in
            try? await Task.sleep(nanoseconds: UInt64(fadeDuration * 1_000_000_000))
            // Skip if the lens was shown again while fading out.
            guard let self, !self.isShown else { return }
            self.window.orderOut(nil)
            self.imageLayer.contents = nil
            self.refractionLayer.contents = nil
        }
    }

    private func fade(to alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = alpha
        }
    }
}
