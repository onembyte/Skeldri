import AVFoundation
import CoreMedia
import Foundation

/// Reconstructs display-ready CoreMedia samples from H.264 configuration and AVCC access units.
final class H264Decoder: @unchecked Sendable {
    weak var displayLayer: AVSampleBufferDisplayLayer?
    private let queue = DispatchQueue(label: "DrawPad.video.decoder", qos: .userInteractive)
    private var formatDescription: CMVideoFormatDescription?

    func configure(_ configuration: VideoConfiguration) {
        queue.async { [weak self] in
            let sps = configuration.sps as NSData, pps = configuration.pps as NSData
            let pointers = [sps.bytes.assumingMemoryBound(to: UInt8.self), pps.bytes.assumingMemoryBound(to: UInt8.self)]
            let sizes = [sps.length, pps.length]
            var format: CMFormatDescription?
            let result = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                parameterSetCount: pointers.count, parameterSetPointers: pointers,
                parameterSetSizes: sizes, nalUnitHeaderLength: 4, formatDescriptionOut: &format)
            if result == noErr { self?.formatDescription = format } else { DrawPadLogger.video.error("Decoder configuration failed: \(result)") }
        }
    }

    func decode(payload: Data) {
        queue.async { [weak self] in
            guard let self, let formatDescription, let (header, accessUnit) = try? VideoEnvelope.decode(payload) else { return }
            var block: CMBlockBuffer?
            let blockStatus = accessUnit.withUnsafeBytes { bytes in
                CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
                    blockLength: accessUnit.count, blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil, offsetToData: 0, dataLength: accessUnit.count, flags: 0, blockBufferOut: &block)
            }
            guard blockStatus == kCMBlockBufferNoErr, let block else { return }
            let copyStatus = accessUnit.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
                return CMBlockBufferReplaceDataBytes(with: baseAddress, blockBuffer: block,
                    offsetIntoDestination: 0, dataLength: accessUnit.count)
            }
            guard copyStatus == kCMBlockBufferNoErr else { return }
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                            presentationTimeStamp: CMTime(seconds: header.presentationTime, preferredTimescale: 90_000),
                                            decodeTimeStamp: .invalid)
            var size = accessUnit.count; var sample: CMSampleBuffer?
            guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block,
                formatDescription: formatDescription, sampleCount: 1, sampleTimingEntryCount: 1,
                sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size,
                sampleBufferOut: &sample) == noErr, let sample else { return }

            // The Mac and iPad do not share a media clock. Asking the display layer
            // to honor the Mac's presentation timestamp can leave every frame queued
            // in the future. Live DrawPad frames should be rendered as soon as they
            // arrive; TCP ordering still preserves the encoded stream sequence.
            CMSetAttachment(sample, key: kCMSampleAttachmentKey_DisplayImmediately,
                            value: kCFBooleanTrue,
                            attachmentMode: kCMAttachmentMode_ShouldNotPropagate)
            DispatchQueue.main.async { [weak self] in
                guard let layer = self?.displayLayer else { return }
                if layer.sampleBufferRenderer.status == .failed { layer.flush() }
                layer.enqueue(sample)
            }
        }
    }

    func reset() { queue.async { [weak self] in self?.formatDescription = nil; DispatchQueue.main.async { self?.displayLayer?.flush() } } }
}
