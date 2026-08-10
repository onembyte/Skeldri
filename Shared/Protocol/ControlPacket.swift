import Foundation

/// Codable control-plane message. Explicit associated values keep mutations deterministic.
enum ControlPacket: Codable, Sendable, Equatable {
    case hello(version: Int, channel: ConnectionChannel, client: String)
    case incompatibleVersion(expected: Int)
    case ping(id: UUID, sentAt: Double)
    case pong(id: UUID, sentAt: Double)
    case display(DisplayDescriptor)
    case strokeBegin(id: UUID, style: StrokeStyle, point: StrokePoint)
    case strokePoints(id: UUID, points: [StrokePoint])
    case strokeEnd(id: UUID)
    case deleteStrokes(ids: [UUID])
    case clear
    case canvasSnapshot([Stroke])
}

struct VideoConfiguration: Codable, Sendable, Equatable {
    let width: Int
    let height: Int
    let sps: Data
    let pps: Data
}

/// Metadata preceding one length-delimited H.264 access unit payload.
struct VideoFrameHeader: Codable, Sendable, Equatable {
    let presentationTime: Double
    let isKeyframe: Bool
}

