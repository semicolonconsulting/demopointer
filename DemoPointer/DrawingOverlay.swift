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
    static let color = NSColor.systemRed

    /// Called when the windows are rebuilt, so the screen capture can pick up the new ones.
    var onWindowsChanged: (() -> Void)?

    private struct Surface {
        let window: NSWindow
        let origin: CGPoint
        let finished: CAShapeLayer
        let current: CAShapeLayer
    }

    private var surfaces: [Surface] = []
    /// Finished strokes, kept as one path.
    private var finishedPath = CGMutablePath()
    private var currentPoints: [CGPoint] = []
    /// The arrow being drawn: from where it started to the pointer.
    private var arrowStart: CGPoint?
    private var arrowEnd: CGPoint?
    private var isShown = false

    var isEmpty: Bool { finishedPath.isEmpty && currentPoints.count < 2 && currentArrow == nil }

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
        currentPoints.append(point)
        guard currentPoints.count >= 2 else { return }
        show()
        setPath(Self.smoothPath(currentPoints), on: \.current)
    }

    /// Ends the current stroke. A press without any movement leaves nothing behind.
    func endStroke() {
        guard !currentPoints.isEmpty else { return }
        if currentPoints.count >= 2 {
            finishedPath.addPath(Self.smoothPath(currentPoints))
            setPath(finishedPath, on: \.finished)
        }
        currentPoints = []
        setPath(nil, on: \.current)
        if isEmpty { hide() }
    }

    /// Stretches the current arrow from where it started to the pointer, starting one if needed.
    func arrow(to point: CGPoint) {
        if arrowStart == nil { arrowStart = point }
        arrowEnd = point
        guard let arrow = currentArrow else { return }
        show()
        setPath(arrow, on: \.current)
    }

    /// Leaves the current arrow where it is. A press without any movement leaves nothing behind.
    func endArrow() {
        guard arrowStart != nil else { return }
        if let arrow = currentArrow {
            finishedPath.addPath(arrow)
            setPath(finishedPath, on: \.finished)
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
        finishedPath = CGMutablePath()
        setPath(nil, on: \.finished)
        setPath(nil, on: \.current)
        hide()
    }

    // MARK: Drawing

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
            let finished = Self.strokeLayer(scale: screen.backingScaleFactor)
            let current = Self.strokeLayer(scale: screen.backingScaleFactor)
            view.layer?.addSublayer(finished)
            view.layer?.addSublayer(current)

            if isShown { window.orderFrontRegardless() }
            return Surface(window: window, origin: screen.frame.origin, finished: finished, current: current)
        }
        setPath(finishedPath.isEmpty ? nil : finishedPath, on: \.finished)
        setPath(currentArrow ?? (currentPoints.count >= 2 ? Self.smoothPath(currentPoints) : nil), on: \.current)
    }

    private static func strokeLayer(scale: CGFloat) -> CAShapeLayer {
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
