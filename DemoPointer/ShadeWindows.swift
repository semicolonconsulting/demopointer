import AppKit

/// Dims every display behind the lens while it's shown, so the magnified area stands out.
/// One click-through window per screen, just below the lens window. Like the lens, the shade
/// shows up in screen shares, but is left out of Demo Pointer's own capture.
@MainActor
final class ShadeWindows {
    private let fadeDuration: TimeInterval = 0.15
    private var windows: [NSWindow] = []
    private var isShown = false
    private var opacity: CGFloat = 0

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
    }

    func show(opacity: CGFloat) {
        guard opacity > 0 else { return hide() }
        if windows.isEmpty { rebuild() }
        if opacity != self.opacity {
            self.opacity = opacity
            for window in windows { window.backgroundColor = NSColor.black.withAlphaComponent(opacity) }
        }
        guard !isShown else { return }
        isShown = true
        for window in windows {
            if !window.isVisible {
                window.alphaValue = 0
                window.orderFrontRegardless()
            }
        }
        fade(to: 1)
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        fade(to: 0) { [weak self] in
            // Skip if the shade was shown again while fading out.
            guard let self, !self.isShown else { return }
            for window in self.windows { window.orderOut(nil) }
        }
    }

    /// One window per screen, matching the current display arrangement.
    private func rebuild() {
        for window in windows { window.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.setFrame(screen.frame, display: false)
            if isShown {
                window.alphaValue = 1
                window.orderFrontRegardless()
            }
            return window
        }
    }

    private func fade(to alpha: CGFloat, completion: (@MainActor () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in windows { window.animator().alphaValue = alpha }
        } completionHandler: {
            MainActor.assumeIsolated { completion?() }
        }
    }
}
