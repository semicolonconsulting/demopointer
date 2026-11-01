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
    private let refractionMask = CAGradientLayer()
    /// Soft frosted tint and inner shading across the band.
    private let bandLayer = CAGradientLayer()
    private let bandMask = CAGradientLayer()
    /// Faint rainbow fringe along the inside of the rim.
    private let fringeLayer = CAGradientLayer()
    private let fringeMask = CAGradientLayer()
    /// Bright specular arcs, strongest top-left with a softer bounce bottom-right.
    private let specularLayer = CAGradientLayer()
    private let specularMask = CAGradientLayer()
    /// Thin translucent outer rim.
    private let rimLayer = CAShapeLayer()
    /// Pixels per point the layers are rendered at; follows the screen the lens is on.
    private var scale: CGFloat = 0

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
        specularLayer.mask = specularMask

        // The masks are radial gradients rather than stroked paths, so every ring fades in and out smoothly.
        for mask in [refractionMask, bandMask, fringeMask, specularMask] {
            mask.type = .radial
            mask.startPoint = CGPoint(x: 0.5, y: 0.5)
            mask.endPoint = CGPoint(x: 1, y: 1)
        }

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

        // The refraction copy is zoomed about 6% more, then faded out towards the middle so only the band shows it.
        let zoom = diameter * 0.06
        refractionLayer.frame = circle.insetBy(dx: -zoom / 2, dy: -zoom / 2)
        refractionLayer.cornerRadius = refractionLayer.frame.width / 2
        let inLayer = CGRect(x: zoom / 2, y: zoom / 2, width: diameter, height: diameter)
        setRing(refractionMask, in: inLayer, stops: [(bandWidth + 2, 0), (bandWidth * 0.4, 1), (0, 1)])

        for layer in [bandLayer, fringeLayer, specularLayer] {
            layer.frame = circle
        }
        // Stops are (points in from the edge, opacity), from the middle outwards.
        let local = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        setRing(bandMask, in: local, stops: [(bandWidth + 3, 0), (bandWidth * 0.5, 0.6), (1, 1), (0, 1)])
        setRing(fringeMask, in: local, stops: [(6, 0), (3, 1), (1.5, 0)])
        setRing(specularMask, in: local, stops: [(4, 0), (1.25, 1), (0, 0.5)])

        rimLayer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        rimLayer.path = CGPath(ellipseIn: circle.insetBy(dx: 0.5, dy: 0.5), transform: nil)
        CATransaction.commit()
    }

    /// Centers the lens on a point in global screen coordinates.
    func center(on point: NSPoint) {
        let side = diameter + margin * 2
        window.setFrameOrigin(NSPoint(x: (point.x - side / 2).rounded(), y: (point.y - side / 2).rounded()))
        updateScale()
    }

    /// Added sublayers render at 1x unless told otherwise, which makes the rim look coarse on Retina screens.
    private func updateScale() {
        let newScale = window.screen?.backingScaleFactor ?? window.backingScaleFactor
        guard newScale != scale else { return }
        scale = newScale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [shadowLayer, imageLayer, refractionLayer, refractionMask, bandLayer, bandMask,
                      fringeLayer, fringeMask, specularLayer, specularMask, rimLayer] {
            layer.contentsScale = scale
        }
        CATransaction.commit()
    }

    /// Points a radial mask at the circle in `rect` and sets its opacity stops, given as distances in points
    /// in from the circle's edge. The mask reaches 1pt past the edge so the outside fades to clear.
    private func setRing(_ mask: CAGradientLayer, in rect: CGRect, stops: [(inset: CGFloat, alpha: CGFloat)]) {
        let radius = rect.width / 2 + 1
        mask.frame = rect.insetBy(dx: -1, dy: -1)
        let all = stops + [(inset: -1, alpha: 0)]
        mask.colors = all.map { NSColor.white.withAlphaComponent($0.alpha).cgColor }
        mask.locations = all.map { NSNumber(value: Double(max(0, (radius - 1 - $0.inset) / radius))) }
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
