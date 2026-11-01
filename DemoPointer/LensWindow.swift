import AppKit
import QuartzCore

/// A transparent, click-through, always-on-top window that draws the circular lens.
@MainActor
final class LensWindow {
    private let window: NSWindow
    /// Space around the circle for the drop shadow, wide enough that the blur fades out before the window edge.
    private let margin: CGFloat = 48
    private let shadowLayer = CALayer()
    private let imageLayer = CALayer()

    /// Width of the glass bevel just inside the edge, where the image is refracted and lit
    /// (see MagnifierController).
    static let bandWidth: CGFloat = 18
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
        shadowLayer.shadowOpacity = 0.25
        shadowLayer.shadowRadius = 12
        shadowLayer.shadowOffset = CGSize(width: 0, height: -6)

        imageLayer.masksToBounds = true
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear

        for layer in [shadowLayer, imageLayer] {
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

        CATransaction.commit()
    }

    /// Centers the lens on a point in global screen coordinates.
    func center(on point: NSPoint) {
        let side = diameter + margin * 2
        window.setFrameOrigin(NSPoint(x: (point.x - side / 2).rounded(), y: (point.y - side / 2).rounded()))
        updateScale()
    }

    /// Added sublayers render at 1x unless told otherwise, which makes edges look coarse on Retina screens.
    private func updateScale() {
        let newScale = window.screen?.backingScaleFactor ?? window.backingScaleFactor
        guard newScale != scale else { return }
        scale = newScale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [shadowLayer, imageLayer] {
            layer.contentsScale = scale
        }
        CATransaction.commit()
    }

    func show(image: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = image
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
