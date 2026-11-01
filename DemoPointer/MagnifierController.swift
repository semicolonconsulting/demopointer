import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

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
    private let shade = ShadeWindows()
    private let cursor = CursorHider()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// Screenshot mode, for App Store screenshots: the lens stays up as if ⌘ were held. Turned on only by
    /// launching with `-ScreenshotMode YES` (scripts/take-screenshots.sh does that).
    private let screenshotMode = UserDefaults.standard.bool(forKey: "ScreenshotMode")
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
        let held = screenshotMode || (settings.isEnabled
            && flags.contains(.command)
            && flags.isDisjoint(with: [.shift, .option, .control]))

        guard held else {
            lens.hide()
            shade.hide()
            cursor.show()
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
            shade.hide()
            cursor.show()
            return
        }

        ensureCapture(displayID: displayID, scale: screen.backingScaleFactor)

        guard let frame = capturer.latestFrame, frame.displayID == displayID,
              let image = magnifiedImage(from: frame.image, around: mouse, on: screen)
        else { return }

        lens.setDiameter(CGFloat(settings.diameter))
        lens.center(on: mouse)
        shade.show(opacity: CGFloat(settings.shadeOpacity))
        lens.show(image: image)
        cursor.hide()
    }

    /// Crops the region under the cursor out of the captured display frame, scales it up to the lens size
    /// in pixels and bends the content near the edge like a ring of glass.
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

        let scale = screen.backingScaleFactor
        let pixels = (settings.diameter * scale).rounded()
        let magnified = cropped
            .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            .transformed(by: CGAffineTransform(scaleX: pixels / width, y: pixels / height))
        let output = CGRect(x: 0, y: 0, width: pixels, height: pixels)
        return ciContext.createCGImage(glassEdge(magnified, in: output, scale: scale), from: output)
    }

    /// Refracts the image through a glass ring that runs around the inside of the lens edge.
    private func glassEdge(_ image: CIImage, in rect: CGRect, scale: CGFloat) -> CIImage {
        let band = LensWindow.bandWidth * scale
        let torus = CIFilter.torusLensDistortion()
        torus.inputImage = image.clampedToExtent()
        torus.center = CGPoint(x: rect.midX, y: rect.midY)
        torus.radius = Float(rect.width / 2 - band / 2)
        torus.width = Float(band)
        torus.refraction = 1.6
        guard let refracted = torus.outputImage else { return image }

        // Fade from the plain image into the refracted ring over the inner part of the band, so there's no seam.
        let fade = CIFilter.radialGradient()
        fade.center = torus.center
        fade.radius0 = Float(rect.width / 2 - band)
        fade.radius1 = Float(rect.width / 2 - band * 0.3)
        fade.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        fade.color1 = .white
        let blend = CIFilter.blendWithAlphaMask()
        blend.inputImage = refracted
        blend.backgroundImage = image
        blend.maskImage = fade.outputImage
        return blend.outputImage?.cropped(to: rect) ?? image
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
