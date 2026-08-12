import CoreMedia
import Foundation
import VideoToolbox

struct EncodedVideoFrame: Sendable {
    let streamID: UUID
    let sequence: UInt64
    let data: Data
    let presentationTime: Double
    let isKeyframe: Bool
}
private struct PixelBufferTransfer: @unchecked Sendable { let buffer: CVImageBuffer; let presentationTime: CMTime }
private final class EncodedFrameContext {
    let streamID: UUID
    let sequence: UInt64

    init(streamID: UUID, sequence: UInt64) {
        self.streamID = streamID
        self.sequence = sequence
    }
}
private struct EncodedOutputTransfer: @unchecked Sendable {
    let status: OSStatus
    let infoFlags: VTEncodeInfoFlags
    let sampleBuffer: CMSampleBuffer?
    let context: EncodedFrameContext
}

/// Real-time H.264 VideoToolbox adapter. Its session and callback are owned by one serial queue.
final class H264Encoder: @unchecked Sendable, ScreenFrameConsumer {
    var onConfiguration: (@Sendable (VideoConfiguration) -> Void)?
    /// Returns false when downstream backpressure dropped the access unit. The
    /// encoder then makes the next submitted frame independently decodable.
    var onFrame: (@Sendable (EncodedVideoFrame) -> Bool)?
    private let queue = DispatchQueue(label: "Skeldri.video.encoder", qos: .userInteractive)
    private var session: VTCompressionSession?
    private var dimensions: CMVideoDimensions?
    private var streamID = UUID()
    private var nextSequence: UInt64 = 0
    private var pendingFrame: PixelBufferTransfer?
    private var encodingInFlight = false
    private var forceNextKeyframe = true
    private var profile: VideoStreamingProfile = .modern
    private var metricsStartedAt = ProcessInfo.processInfo.systemUptime
    private var metricsEncodedFrames = 0
    private var metricsSentFrames = 0
    private var metricsSentBytes = 0

    func consume(_ sampleBuffer: CMSampleBuffer) {
        guard let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let transfer = PixelBufferTransfer(buffer: image, presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        queue.async { [weak self] in
            guard let self else { return }
            // Capture may outrun hardware encoding. Retain only the newest raw
            // frame; dropping before encoding never breaks H.264 dependencies.
            pendingFrame = transfer
            encodePendingFrameIfPossible()
        }
    }

    func invalidate() { queue.async { [weak self] in self?.invalidateCurrentSession() } }
    func requestKeyframe() { queue.async { [weak self] in self?.forceNextKeyframe = true } }
    func setProfile(_ profile: VideoStreamingProfile) {
        queue.async { [weak self] in
            guard let self, self.profile != profile else { return }
            self.profile = profile
            self.invalidateCurrentSession()
        }
    }

    private func encodePendingFrameIfPossible() {
        guard !encodingInFlight, let frame = pendingFrame else { return }
        pendingFrame = nil
        let image = frame.buffer
        let width = Int32(CVPixelBufferGetWidth(image)), height = Int32(CVPixelBufferGetHeight(image))
        if dimensions?.width != width || dimensions?.height != height { recreate(width: width, height: height) }
        guard let session else { return }

        let sequence = nextSequence
        nextSequence &+= 1
        let context = Unmanaged.passRetained(EncodedFrameContext(streamID: streamID, sequence: sequence))
        let frameProperties: CFDictionary? = forceNextKeyframe
            ? [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary
            : nil
        forceNextKeyframe = false
        encodingInFlight = true
        var flags = VTEncodeInfoFlags()
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: image,
            presentationTimeStamp: frame.presentationTime,
            duration: CMTime(value: 1, timescale: CMTimeScale(profile.framesPerSecond)),
            frameProperties: frameProperties,
            sourceFrameRefcon: context.toOpaque(),
            infoFlagsOut: &flags
        )
        if status != noErr {
            context.release()
            encodingInFlight = false
            forceNextKeyframe = true
            SkeldriLogger.video.error("Encode failed: \(status)")
            encodePendingFrameIfPossible()
        }
    }

    private func recreate(width: Int32, height: Int32) {
        invalidateCurrentSession()
        streamID = UUID()
        nextSequence = 0
        forceNextKeyframe = true
        resetMetrics()
        var created: VTCompressionSession?
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = VTCompressionSessionCreate(allocator: kCFAllocatorDefault, width: width, height: height,
                                                codecType: kCMVideoCodecType_H264, encoderSpecification: nil,
                                                imageBufferAttributes: nil, compressedDataAllocator: nil,
                                                outputCallback: h264OutputCallback, refcon: context,
                                                compressionSessionOut: &created)
        guard status == noErr, let created else { SkeldriLogger.video.error("Encoder creation failed: \(status)"); return }
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_ExpectedFrameRate,
                             value: profile.framesPerSecond as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AverageBitRate,
                             value: profile.averageBitRate as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_DataRateLimits,
                             value: [profile.averageBitRate / 8, 1] as CFArray)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
                             value: profile.framesPerSecond as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 1 as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality, value: kCFBooleanTrue)
        VTCompressionSessionPrepareToEncodeFrames(created)
        session = created; dimensions = CMVideoDimensions(width: width, height: height)
        SkeldriLogger.video.info("Encoder started at \(width)x\(height)")
    }

    private func invalidateCurrentSession() {
        if let session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        session = nil
        dimensions = nil
        pendingFrame = nil
        encodingInFlight = false
        forceNextKeyframe = true
    }

    fileprivate func receive(_ transfer: EncodedOutputTransfer) {
        queue.async { [weak self] in
            self?.processEncodedFrame(
                status: transfer.status,
                infoFlags: transfer.infoFlags,
                sampleBuffer: transfer.sampleBuffer,
                context: transfer.context
            )
        }
    }

    private func processEncodedFrame(status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?, context: EncodedFrameContext) {
        guard context.streamID == streamID else { return }
        defer {
            encodingInFlight = false
            encodePendingFrameIfPossible()
        }
        guard status == noErr, !infoFlags.contains(.frameDropped), let sampleBuffer,
              let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let block = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            forceNextKeyframe = true
            return
        }
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
        let keyframe = attachments?.first?[kCMSampleAttachmentKey_NotSync] == nil
        if keyframe {
            var spsPointer: UnsafePointer<UInt8>?, spsSize = 0, count = 0
            var ppsPointer: UnsafePointer<UInt8>?, ppsSize = 0
            let spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 0, parameterSetPointerOut: &spsPointer, parameterSetSizeOut: &spsSize, parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
            let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 1, parameterSetPointerOut: &ppsPointer, parameterSetSizeOut: &ppsSize, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
            if spsStatus == noErr, ppsStatus == noErr, let spsPointer, let ppsPointer, let dimensions {
                onConfiguration?(VideoConfiguration(streamID: streamID, width: Int(dimensions.width), height: Int(dimensions.height), sps: Data(bytes: spsPointer, count: spsSize), pps: Data(bytes: ppsPointer, count: ppsSize)))
            }
        }
        var length = 0; var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == kCMBlockBufferNoErr, let pointer else { return }
        let accepted = onFrame?(EncodedVideoFrame(
            streamID: context.streamID,
            sequence: context.sequence,
            data: Data(bytes: pointer, count: length),
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds,
            isKeyframe: keyframe
        )) ?? false
        recordMetrics(frameBytes: length, accepted: accepted)
        if !accepted { forceNextKeyframe = true }
    }

    private func resetMetrics() {
        metricsStartedAt = ProcessInfo.processInfo.systemUptime
        metricsEncodedFrames = 0
        metricsSentFrames = 0
        metricsSentBytes = 0
    }

    private func recordMetrics(frameBytes: Int, accepted: Bool) {
        metricsEncodedFrames += 1
        if accepted {
            metricsSentFrames += 1
            metricsSentBytes += frameBytes
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - metricsStartedAt
        guard elapsed >= 2 else { return }
        let encodedFPS = Double(metricsEncodedFrames) / elapsed
        let sentFPS = Double(metricsSentFrames) / elapsed
        let megabitsPerSecond = Double(metricsSentBytes * 8) / elapsed / 1_000_000
        SkeldriLogger.video.info(
            "Video metrics encoded=\(encodedFPS, format: .fixed(precision: 1))fps sent=\(sentFPS, format: .fixed(precision: 1))fps bitrate=\(megabitsPerSecond, format: .fixed(precision: 2))Mbps"
        )
        resetMetrics()
    }
}

private let h264OutputCallback: VTCompressionOutputCallback = { refcon, sourceFrameRefcon, status, flags, sampleBuffer in
    guard let refcon, let sourceFrameRefcon else { return }
    let context = Unmanaged<EncodedFrameContext>.fromOpaque(sourceFrameRefcon).takeRetainedValue()
    Unmanaged<H264Encoder>.fromOpaque(refcon).takeUnretainedValue().receive(EncodedOutputTransfer(
        status: status,
        infoFlags: flags,
        sampleBuffer: sampleBuffer,
        context: context
    ))
}
