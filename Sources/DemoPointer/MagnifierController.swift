import AppKit
import CoreImage

/// Polls the Command key and cursor position, and drives the lens while Command is held.
///
/// Polling `NSEvent.modifierFlags` works without Accessibility or Input Monitoring
/// permission, unlike a global key event monitor.
@MainActor
final class MagnifierController: NSObject {
    /// How long to keep the capture stream warm after the lens is released, so the
    /// next press shows the lens instantly.
    private let keepWarmInterval: TimeInterval = 30
    private let retryInterval: TimeInterval = 2

    private let settings = Settings.shared
    private let capturer = ScreenCapturer()
    private let lens = LensWindow()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    private var timer: Timer?
    private var captureTask: Task<Void, Never>?
    private var capturingDisplayID: CGDirectDisplayID?
    private var lastHeld = Date.distantPast
    private var lastFailure = Date.distantPast

    /// Called when capture fails, typically because Screen Recording permission is missing.
    var onCaptureFailure: ((Error) -> Void)?

    func start() {
        let timer = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func tick() {
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Only plain Command, so shortcuts like Cmd+Shift+4 don't pop the lens.
        let held = settings.isEnabled
            && flags.contains(.command)
            && flags.isDisjoint(with: [.shift, .option, .control])

        guard held else {
            lens.hide()
            if Date().timeIntervalSince(lastHeld) > keepWarmInterval {
                stopCapture()
            }
            return
        }
        lastHeld = Date()

        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }),
              let displayID = screen.displayID
        else {
            lens.hide()
            return
        }

        ensureCapture(displayID: displayID, scale: screen.backingScaleFactor)

        guard let frame = capturer.latestFrame, frame.displayID == displayID,
              let image = magnifiedImage(from: frame.image, around: mouse, on: screen)
        else { return }

        lens.setDiameter(CGFloat(settings.diameter))
        lens.center(on: mouse)
        lens.show(image: image)
    }

    /// Crops the region under the cursor out of the captured display frame.
    /// The lens layer scales it up to the lens size.
    private func magnifiedImage(from frame: CIImage, around mouse: NSPoint, on screen: NSScreen) -> CGImage? {
        let extent = frame.extent
        // Pixels per point. Both CIImage and Cocoa screen coordinates have a bottom-left origin.
        let scaleX = extent.width / screen.frame.width
        let scaleY = extent.height / screen.frame.height
        let center = CGPoint(
            x: (mouse.x - screen.frame.minX) * scaleX,
            y: (mouse.y - screen.frame.minY) * scaleY
        )
        let sourcePoints = settings.diameter / settings.zoom
        let width = (sourcePoints * scaleX).rounded()
        let height = (sourcePoints * scaleY).rounded()
        let rect = CGRect(
            x: (center.x - width / 2).rounded(),
            y: (center.y - height / 2).rounded(),
            width: width,
            height: height
        )

        // Fill anything beyond the screen edge with black.
        let background = CIImage(color: .black).cropped(to: rect)
        let cropped = frame.cropped(to: rect).composited(over: background)
        return ciContext.createCGImage(cropped, from: rect)
    }

    private func ensureCapture(displayID: CGDirectDisplayID, scale: CGFloat) {
        guard capturingDisplayID != displayID,
              Date().timeIntervalSince(lastFailure) > retryInterval
        else { return }

        capturingDisplayID = displayID
        let capturer = self.capturer
        let previous = captureTask
        captureTask = Task {
            await previous?.value
            do {
                try await capturer.start(displayID: displayID, scale: scale)
            } catch {
                self.captureFailed(error, displayID: displayID)
            }
        }
    }

    private func captureFailed(_ error: Error, displayID: CGDirectDisplayID) {
        NSLog("DemoPointer: could not start capture: \(error.localizedDescription)")
        if capturingDisplayID == displayID {
            capturingDisplayID = nil
        }
        lastFailure = Date()
        onCaptureFailure?(error)
    }

    private func stopCapture() {
        guard capturingDisplayID != nil else { return }
        capturingDisplayID = nil
        let capturer = self.capturer
        let previous = captureTask
        captureTask = Task {
            await previous?.value
            await capturer.stop()
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}
