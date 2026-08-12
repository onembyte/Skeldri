import CoreMedia
import ScreenCaptureKit

protocol ScreenFrameConsumer: AnyObject { func consume(_ sampleBuffer: CMSampleBuffer) }

/// ScreenCaptureKit adapter. Capture output is isolated on a dedicated serial queue.
final class ScreenCaptureManager: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    weak var consumer: ScreenFrameConsumer?
    private let queue = DispatchQueue(label: "Skeldri.capture", qos: .userInteractive)
    private let stateLock = NSLock()
    private var stream: SCStream?
    private var fallbackTask: Task<Void, Never>?
    private var receivedStreamFrame = false

    @MainActor func start(display: SCDisplay, excluding applications: [SCRunningApplication],
                          profile: VideoStreamingProfile = .modern) async throws {
        await stop()
        let filter = SCContentFilter(display: display, excludingApplications: applications, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        let scale = min(1, Double(profile.maximumDimension) / Double(max(display.width, display.height)))
        configuration.width = Int(Double(display.width) * scale)
        configuration.height = Int(Double(display.height) * scale)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(profile.framesPerSecond))
        configuration.showsCursor = true
        configuration.capturesAudio = false
        // Two surfaces absorb normal scheduling jitter without allowing capture
        // itself to become a visible multi-frame latency reservoir.
        configuration.queueDepth = 2
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        self.stream = stream

        stateLock.withLock { receivedStreamFrame = false }
        fallbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.runScreenshotFallback(filter: filter, configuration: configuration,
                                              framesPerSecond: profile.framesPerSecond)
        }
        try await stream.startCapture()
        SkeldriLogger.capture.info("Capture started at \(configuration.width)x\(configuration.height)")
    }

    @MainActor func stop() async {
        fallbackTask?.cancel()
        fallbackTask = nil
        guard let stream else { return }
        do { try await stream.stopCapture() } catch { SkeldriLogger.capture.error("Capture stop failed: \(error.localizedDescription)") }
        self.stream = nil
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) { SkeldriLogger.capture.error("Capture stopped: \(error.localizedDescription)") }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        stateLock.withLock { receivedStreamFrame = true }
        consumer?.consume(sampleBuffer)
    }

    /// Some beta ScreenCaptureKit builds successfully start an `SCStream` but do
    /// not deliver output. A bounded screenshot loop keeps mirroring functional
    /// until the primary stream emits its first frame, then exits automatically.
    @MainActor
    private func runScreenshotFallback(filter: SCContentFilter, configuration: SCStreamConfiguration,
                                       framesPerSecond: Int) async {
        guard !stateLock.withLock({ receivedStreamFrame }) else { return }
        SkeldriLogger.capture.warning("No SCStream frames received; starting screenshot fallback")
        while !Task.isCancelled, !stateLock.withLock({ receivedStreamFrame }) {
            do {
                let sample = try await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: configuration)
                consumer?.consume(sample)
            } catch {
                SkeldriLogger.capture.error("Screenshot fallback failed: \(error.localizedDescription)")
                return
            }
            let delay = max(1, 1_000 / framesPerSecond)
            try? await Task.sleep(for: .milliseconds(delay))
        }
    }
}
