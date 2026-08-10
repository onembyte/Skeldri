import CoreMedia
import ScreenCaptureKit

protocol ScreenFrameConsumer: AnyObject { func consume(_ sampleBuffer: CMSampleBuffer) }

/// ScreenCaptureKit adapter. Capture output is isolated on a dedicated serial queue.
final class ScreenCaptureManager: NSObject, SCStreamOutput, SCStreamDelegate {
    weak var consumer: ScreenFrameConsumer?
    private let queue = DispatchQueue(label: "DrawPad.capture", qos: .userInteractive)
    private var stream: SCStream?

    func start(display: SCDisplay, excluding applications: [SCRunningApplication]) async throws {
        await stop()
        let filter = SCContentFilter(display: display, excludingApplications: applications, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        let scale = min(1, 1600 / Double(max(display.width, display.height)))
        configuration.width = Int(Double(display.width) * scale)
        configuration.height = Int(Double(display.height) * scale)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.queueDepth = 3
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        self.stream = stream
        try await stream.startCapture()
        DrawPadLogger.capture.info("Capture started at \(configuration.width)x\(configuration.height)")
    }

    func stop() async {
        guard let stream else { return }
        do { try await stream.stopCapture() } catch { DrawPadLogger.capture.error("Capture stop failed: \(error.localizedDescription)") }
        self.stream = nil
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) { DrawPadLogger.capture.error("Capture stopped: \(error.localizedDescription)") }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        consumer?.consume(sampleBuffer)
    }
}

