import AppKit
import QuartzCore

/// Pen strokes and arrows drawn over the whole screen: while ⌥ Option is held by itself, the pointer leaves
/// a line behind it; with ⇧ Shift added, it pulls out an arrow instead. They stay until they're cleared.
///
/// One click-through window per screen, below the shade and the lens, so the shade dims the drawing and
/// the lens magnifies it. Points are in global screen coordinates (bottom-left origin), so a stroke can
/// cross from one display to another.
@MainActor
final class DrawingOverlay {
    static let lineWidth: CGFloat = 5

    /// The colour for strokes and arrows started from now on. Ones already drawn keep their colour.
    var color = NSColor.systemRed

    /// Called when the windows are rebuilt, so the screen capture can pick up the new ones.
    var onWindowsChanged: (() -> Void)?

    private struct Surface {
        let window: NSWindow
        let origin: CGPoint
        let scale: CGFloat
        /// Holds one layer per finished stroke, so each keeps its own colour.
        let finished: CALayer
        let current: CAShapeLayer
    }

    private struct Stroke {
        let path: CGPath
        let color: NSColor
    }

    private var surfaces: [Surface] = []
    private var finished: [Stroke] = []
    /// The colour of the stroke or arrow being drawn, fixed when it starts.
    private var currentColor = NSColor.systemRed
    private var currentPoints: [CGPoint] = []
    /// The arrow being drawn: from where it started to the pointer.
    private var arrowStart: CGPoint?
    private var arrowEnd: CGPoint?
    private var isShown = false

    var isEmpty: Bool { finished.isEmpty && currentPoints.count < 2 && currentArrow == nil }

    /// The overlay's window numbers, so the capture can include them even though it leaves out the rest of
    /// Demo Pointer's windows.
    var windowIDs: [CGWindowID] { surfaces.map { CGWindowID($0.window.windowNumber) } }

    init() {
        rebuild()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuild()
                self?.onWindowsChanged?()
            }
        }
    }

    /// Extends the current stroke to the pointer, starting one if needed.
    func add(_ point: CGPoint) {
        if let last = currentPoints.last, hypot(point.x - last.x, point.y - last.y) < 1 { return }
        if currentPoints.isEmpty { startCurrent() }
        currentPoints.append(point)
        guard currentPoints.count >= 2 else { return }
        show()
        setPath(Self.smoothPath(currentPoints), on: \.current)
    }

    /// Ends the current stroke. A press without any movement leaves nothing behind.
    func endStroke() {
        guard !currentPoints.isEmpty else { return }
        if currentPoints.count >= 2 {
            addFinished(Self.smoothPath(currentPoints))
        }
        currentPoints = []
        setPath(nil, on: \.current)
        if isEmpty { hide() }
    }

    /// Stretches the current arrow from where it started to the pointer, starting one if needed.
    func arrow(to point: CGPoint) {
        if arrowStart == nil {
            arrowStart = point
            startCurrent()
        }
        arrowEnd = point
        guard let arrow = currentArrow else { return }
        show()
        setPath(arrow, on: \.current)
    }

    /// Leaves the current arrow where it is. A press without any movement leaves nothing behind.
    func endArrow() {
        guard arrowStart != nil else { return }
        if let arrow = currentArrow {
            addFinished(arrow)
        }
        arrowStart = nil
        arrowEnd = nil
        setPath(nil, on: \.current)
        if isEmpty { hide() }
    }

    func clear() {
        currentPoints = []
        arrowStart = nil
        arrowEnd = nil
        finished = []
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for surface in surfaces { surface.finished.sublayers = nil }
        CATransaction.commit()
        setPath(nil, on: \.current)
        hide()
    }

    // MARK: Drawing

    /// Fixes the colour of a stroke or arrow as it starts.
    private func startCurrent() {
        currentColor = color
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for surface in surfaces { surface.current.strokeColor = color.cgColor }
        CATransaction.commit()
    }

    private func addFinished(_ path: CGPath) {
        let stroke = Stroke(path: path, color: currentColor)
        finished.append(stroke)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for surface in surfaces { surface.finished.addSublayer(Self.layer(for: stroke, on: surface)) }
        CATransaction.commit()
    }

    private static func layer(for stroke: Stroke, on surface: Surface) -> CAShapeLayer {
        let layer = strokeLayer(scale: surface.scale, color: stroke.color)
        var shift = CGAffineTransform(translationX: -surface.origin.x, y: -surface.origin.y)
        layer.path = stroke.path.copy(using: &shift)
        return layer
    }

    /// A curve through the midpoints of the polled positions, so the line doesn't look jagged.
    private static func smoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            path.addLines(between: points)
            return path
        }
        for index in 1..<(points.count - 1) {
            let point = points[index], next = points[index + 1]
            path.addQuadCurve(to: CGPoint(x: (point.x + next.x) / 2, y: (point.y + next.y) / 2), control: point)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }

    /// The current arrow, once it's long enough to tell which way it points.
    private var currentArrow: CGPath? {
        guard let start = arrowStart, let end = arrowEnd,
              hypot(end.x - start.x, end.y - start.y) >= 6 else { return nil }
        return Self.arrowPath(from: start, to: end)
    }

    /// A line with an open arrowhead at `end`.
    private static func arrowPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = min(22, hypot(end.x - start.x, end.y - start.y) * 0.6)
        let spread = CGFloat.pi / 7
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        path.move(to: CGPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread)))
        path.addLine(to: end)
        path.addLine(to: CGPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread)))
        return path
    }

    private func setPath(_ path: CGPath?, on layer: KeyPath<Surface, CAShapeLayer>) {
        // Only the current stroke changes in place; finished ones get layers of their own.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for surface in surfaces {
            var shift = CGAffineTransform(translationX: -surface.origin.x, y: -surface.origin.y)
            surface[keyPath: layer].path = path.flatMap { $0.copy(using: &shift) }
        }
        CATransaction.commit()
    }

    // MARK: Windows

    private func show() {
        guard !isShown else { return }
        isShown = true
        for surface in surfaces { surface.window.orderFrontRegardless() }
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        for surface in surfaces { surface.window.orderOut(nil) }
    }

    /// One window per screen, matching the current display arrangement.
    private func rebuild() {
        for surface in surfaces { surface.window.orderOut(nil) }
        surfaces = NSScreen.screens.map { screen in
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            // Below the shade (screenSaver - 1) and the lens (screenSaver).
            window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 2)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.setFrame(screen.frame, display: false)

            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            window.contentView = view
            let finishedLayer = CALayer()
            finishedLayer.frame = view.bounds
            let current = Self.strokeLayer(scale: screen.backingScaleFactor, color: currentColor)
            view.layer?.addSublayer(finishedLayer)
            view.layer?.addSublayer(current)

            if isShown { window.orderFrontRegardless() }
            let surface = Surface(window: window, origin: screen.frame.origin, scale: screen.backingScaleFactor,
                                  finished: finishedLayer, current: current)
            for stroke in finished { finishedLayer.addSublayer(Self.layer(for: stroke, on: surface)) }
            return surface
        }
        setPath(currentArrow ?? (currentPoints.count >= 2 ? Self.smoothPath(currentPoints) : nil), on: \.current)
    }

    private static func strokeLayer(scale: CGFloat, color: NSColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.contentsScale = scale
        layer.fillColor = nil
        layer.strokeColor = color.cgColor
        layer.lineWidth = lineWidth
        layer.lineCap = .round
        layer.lineJoin = .round
        return layer
    }
}
