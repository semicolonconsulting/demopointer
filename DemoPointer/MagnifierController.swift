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

    /// Bends the image near the edge like a rounded glass bevel: untouched in the middle, then pulling in
    /// more and more of what lies just outside the lens towards the rim. The bevel catches a little light too.
    private func glassEdge(_ image: CIImage, in rect: CGRect, scale: CGFloat) -> CIImage {
        let bevel = LensWindow.bandWidth * scale
        let radius = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var refracted: CIImage
        if #available(macOS 15, *), let kernel = Self.bevelKernel {
            refracted = kernel.apply(
                extent: rect,
                roiCallback: { _, r in r.insetBy(dx: -bevel * 2, dy: -bevel * 2) },
                image: image.clampedToExtent(),
                arguments: [CIVector(cgPoint: center), radius, bevel, 1.2]
            ) ?? image
        } else {
            refracted = torusEdge(image, center: center, radius: radius, band: bevel)
        }

        let sheen = CIFilter.radialGradient()
        sheen.center = center
        sheen.radius0 = Float(radius - bevel)
        sheen.radius1 = Float(radius)
        sheen.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        sheen.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        if let light = sheen.outputImage {
            refracted = light.composited(over: refracted)
        }
        return refracted.cropped(to: rect)
    }

    /// Displacement for a glass bevel with a round profile: none where the bevel starts, steepest at the rim.
    @available(macOS 15, *)
    private static let bevelKernel: CIWarpKernel? = {
        let source = """
            #include <CoreImage/CoreImage.h>
            using namespace metal;
            [[stitchable]] float2 glassBevel(float2 center, float radius, float bevel, float strength,
                                             coreimage::destination dest) {
                float2 v = dest.coord() - center;
                float r = length(v);
                float t = clamp((r - (radius - bevel)) / bevel, 0.0, 1.0);
                float pull = strength * bevel * (1.0 - sqrt(1.0 - t * t));
                return center + v * ((r + pull) / max(r, 0.0001));
            }
            """
        do {
            return try CIKernel.kernels(withMetalString: source).first as? CIWarpKernel
        } catch {
            NSLog("DemoPointer: could not build the glass kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    /// Before macOS 15, approximates the bevel with the built-in torus lens, faded in from the middle.
    private func torusEdge(_ image: CIImage, center: CGPoint, radius: CGFloat, band: CGFloat) -> CIImage {
        let torus = CIFilter.torusLensDistortion()
        torus.inputImage = image.clampedToExtent()
        torus.center = center
        torus.radius = Float(radius - band / 2)
        torus.width = Float(band)
        torus.refraction = 1.6
        guard let refracted = torus.outputImage else { return image }

        // Fade from the plain image into the refracted ring over the inner part of the band, so there's no seam.
        let fade = CIFilter.radialGradient()
        fade.center = center
        fade.radius0 = Float(radius - band)
        fade.radius1 = Float(radius - band * 0.3)
        fade.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        fade.color1 = .white
        let blend = CIFilter.blendWithAlphaMask()
        blend.inputImage = refracted
        blend.backgroundImage = image
        blend.maskImage = fade.outputImage
        return blend.outputImage ?? image
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
