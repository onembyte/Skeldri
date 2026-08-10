import CoreMedia
import Foundation
import VideoToolbox

struct EncodedVideoFrame: Sendable {
    let streamID: UUID
    let data: Data
    let presentationTime: Double
    let isKeyframe: Bool
}
private struct PixelBufferTransfer: @unchecked Sendable { let buffer: CVImageBuffer; let presentationTime: CMTime }

/// Real-time H.264 VideoToolbox adapter. Its session and callback are owned by one serial queue.
final class H264Encoder: @unchecked Sendable, ScreenFrameConsumer {
    var onConfiguration: (@Sendable (VideoConfiguration) -> Void)?
    var onFrame: (@Sendable (EncodedVideoFrame) -> Void)?
    private let queue = DispatchQueue(label: "DrawPad.video.encoder", qos: .userInteractive)
    private var session: VTCompressionSession?
    private var dimensions: CMVideoDimensions?
    private var streamID = UUID()

    func consume(_ sampleBuffer: CMSampleBuffer) {
        guard let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = Int32(CVPixelBufferGetWidth(image)), height = Int32(CVPixelBufferGetHeight(image))
        let transfer = PixelBufferTransfer(buffer: image, presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        queue.async { [weak self] in self?.encode(transfer.buffer, width: width, height: height, pts: transfer.presentationTime) }
    }

    func invalidate() { queue.async { [weak self] in self?.invalidateCurrentSession() } }

    private func encode(_ image: CVImageBuffer, width: Int32, height: Int32, pts: CMTime) {
        if dimensions?.width != width || dimensions?.height != height { recreate(width: width, height: height) }
        guard let session else { return }
        var flags = VTEncodeInfoFlags()
        let status = VTCompressionSessionEncodeFrame(session, imageBuffer: image, presentationTimeStamp: pts,
                                                      duration: CMTime(value: 1, timescale: 30), frameProperties: nil,
                                                      sourceFrameRefcon: nil, infoFlagsOut: &flags)
        if status != noErr { DrawPadLogger.video.error("Encode failed: \(status)") }
    }

    private func recreate(width: Int32, height: Int32) {
        invalidateCurrentSession()
        streamID = UUID()
        var created: VTCompressionSession?
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = VTCompressionSessionCreate(allocator: kCFAllocatorDefault, width: width, height: height,
                                                codecType: kCMVideoCodecType_H264, encoderSpecification: nil,
                                                imageBufferAttributes: nil, compressedDataAllocator: nil,
                                                outputCallback: h264OutputCallback, refcon: context,
                                                compressionSessionOut: &created)
        guard status == noErr, let created else { DrawPadLogger.video.error("Encoder creation failed: \(status)"); return }
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 30 as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AverageBitRate, value: 4_000_000 as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 60 as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(created)
        session = created; dimensions = CMVideoDimensions(width: width, height: height)
        DrawPadLogger.video.info("Encoder started at \(width)x\(height)")
    }

    private func invalidateCurrentSession() {
        if let session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        session = nil
        dimensions = nil
    }

    fileprivate func receive(status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) {
        guard status == noErr, !infoFlags.contains(.frameDropped), let sampleBuffer,
              let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
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
        onFrame?(EncodedVideoFrame(streamID: streamID, data: Data(bytes: pointer, count: length), presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds, isKeyframe: keyframe))
    }
}

private let h264OutputCallback: VTCompressionOutputCallback = { refcon, _, status, flags, sampleBuffer in
    guard let refcon else { return }
    Unmanaged<H264Encoder>.fromOpaque(refcon).takeUnretainedValue().receive(status: status, infoFlags: flags, sampleBuffer: sampleBuffer)
}
