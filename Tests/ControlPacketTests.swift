import Foundation
import Testing

struct ControlPacketTests {
    @Test func codableRoundTrips() throws {
        let id = UUID(), point = StrokePoint(x: 0.2, y: 0.3, timestamp: 1, pressure: 1)
        let display = DisplayDescriptor(id: 7, name: "Studio Display", width: 2560, height: 1440)
        let values: [ControlPacket] = [.hello(version: ProtocolVersion.current, channel: .control, client: "iPad"), .ping(id:id, sentAt:1), .pong(id:id, sentAt:1), .videoAcknowledgement(streamID: id, sequence: 7, requiresKeyframe: false), .displays([display]), .display(display), .selectDisplay(id: display.id), .strokeBegin(id:id, style:.defaultPen, point:point), .strokePoints(id:id, points:[point]), .strokeEnd(id:id), .deleteStrokes(ids:[id]), .clear]
        for value in values { #expect(try JSONDecoder().decode(ControlPacket.self, from: JSONEncoder().encode(value)) == value) }
    }
    @Test func videoEnvelopeRoundTripAndTruncation() throws {
        let header = VideoFrameHeader(streamID: UUID(), sequence: 9, presentationTime: 42.5, isKeyframe: true)
        let bytes = Data([1, 2, 3, 4])
        let decoded = try VideoEnvelope.decode(VideoEnvelope.encode(header: header, accessUnit: bytes))
        #expect(decoded.0 == header); #expect(decoded.1 == bytes)
        #expect(throws: VideoEnvelopeError.self) { try VideoEnvelope.decode(Data([0, 0, 0])) }
    }
}
