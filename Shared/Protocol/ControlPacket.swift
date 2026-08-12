import Foundation

/// Codable control-plane message. Explicit associated values keep mutations deterministic.
enum ControlPacket: Codable, Sendable, Equatable {
    case hello(version: Int, channel: ConnectionChannel, client: String)
    case incompatibleVersion(expected: Int)
    case ping(id: UUID, sentAt: Double)
    case pong(id: UUID, sentAt: Double)
    case videoAcknowledgement(streamID: UUID, sequence: UInt64, requiresKeyframe: Bool)
    case inputMode(SkeldriInputMode)
    case trackpad(TrackpadEvent)
    case displays([DisplayDescriptor])
    case display(DisplayDescriptor)
    case selectDisplay(id: UInt32)
    case strokeBegin(id: UUID, style: StrokeStyle, point: StrokePoint)
    case strokePoints(id: UUID, points: [StrokePoint])
    case strokeEnd(id: UUID)
    case deleteStrokes(ids: [UUID])
    case clear
    case canvasSnapshot([Stroke])
}

struct VideoConfiguration: Codable, Sendable, Equatable {
    /// Identifies one encoder lifetime so delayed frames from an old display can be rejected.
    let streamID: UUID
    let width: Int
    let height: Int
    let sps: Data
    let pps: Data
}

/// Metadata preceding one length-delimited H.264 access unit payload.
struct VideoFrameHeader: Codable, Sendable, Equatable {
    let streamID: UUID
    let sequence: UInt64
    let presentationTime: Double
    let isKeyframe: Bool
}

enum VideoEnvelopeError: Error { case truncated, invalidHeader }

/// Packs small JSON timing metadata before the encoded AVCC access unit.
enum VideoEnvelope {
    static func encode(header: VideoFrameHeader, accessUnit: Data) throws -> Data {
        let metadata = try JSONEncoder().encode(header)
        var length = UInt32(metadata.count).bigEndian
        var result = withUnsafeBytes(of: &length) { Data($0) }
        result.append(metadata); result.append(accessUnit)
        return result
    }

    static func decode(_ data: Data) throws -> (VideoFrameHeader, Data) {
        guard data.count >= 4 else { throw VideoEnvelopeError.truncated }
        let length = data.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length <= data.count - 4 else { throw VideoEnvelopeError.truncated }
        let split = 4 + Int(length)
        guard let header = try? JSONDecoder().decode(VideoFrameHeader.self, from: data.subdata(in: 4..<split)) else { throw VideoEnvelopeError.invalidHeader }
        return (header, data.subdata(in: split..<data.count))
    }
}
