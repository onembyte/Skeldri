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
            let parameters = [configuration.sps, configuration.pps]
            parameters.withUnsafeBufferPointer { buffer in
                let pointers = buffer.map { data in data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! } }
                let sizes = buffer.map(\.count)
                var format: CMFormatDescription?
                let result = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count, parameterSetPointers: pointers,
                    parameterSetSizes: sizes, nalUnitHeaderLength: 4, formatDescriptionOut: &format)
                if result == noErr { self?.formatDescription = format } else { DrawPadLogger.video.error("Decoder configuration failed: \(result)") }
            }
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
            DispatchQueue.main.async { [weak self] in
                guard let layer = self?.displayLayer else { return }
                if layer.sampleBufferRenderer.status == .failed { layer.flush() }
                layer.enqueue(sample)
            }
        }
    }

    func reset() { queue.async { [weak self] in self?.formatDescription = nil; DispatchQueue.main.async { self?.displayLayer?.flush() } } }
}
