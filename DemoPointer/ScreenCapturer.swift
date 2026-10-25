import AppKit
import CoreImage
import ScreenCaptureKit

enum CaptureError: Error {
    case displayNotFound
}

/// Streams one display with ScreenCaptureKit and keeps the most recent frame.
/// Our own windows (the lens) are excluded so the lens never magnifies itself.
final class ScreenCapturer: NSObject, SCStreamOutput, SCStreamDelegate {
    struct Frame {
        let image: CIImage
        let displayID: CGDirectDisplayID
    }

    private let lock = NSLock()
    private var latest: Frame?
    private var currentDisplayID: CGDirectDisplayID?
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "consulting.semicolon.DemoPointer.capture")

    var latestFrame: Frame? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    func start(displayID: CGDirectDisplayID, scale: CGFloat) async throws {
        await stop()

        // Include off-screen windows: the lens is hidden when capture starts, and an app with no
        // on-screen windows is left out of `applications`, which would let the lens magnify itself.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        let ownApp = content.applications.filter { $0.processID == pid }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 4

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)

        setCurrentDisplay(displayID)

        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        resetFrames()

        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }

    // NSLock can't be used directly from async functions, so these wrap it synchronously.
    private func resetFrames() {
        lock.lock()
        latest = nil
        currentDisplayID = nil
        lock.unlock()
    }

    private func setCurrentDisplay(_ displayID: CGDirectDisplayID) {
        lock.lock()
        currentDisplayID = displayID
        lock.unlock()
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer
        else { return }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        lock.lock()
        if let displayID = currentDisplayID {
            latest = Frame(image: image, displayID: displayID)
        }
        lock.unlock()
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("DemoPointer: capture stopped: \(error.localizedDescription)")
        lock.lock()
        latest = nil
        lock.unlock()
    }
}
