import Foundation
import Testing

struct ControlPacketTests {
    @Test func codableRoundTrips() throws {
        let id = UUID(), point = StrokePoint(x: 0.2, y: 0.3, timestamp: 1, pressure: 1)
        let display = DisplayDescriptor(id: 7, name: "Studio Display", width: 2560, height: 1440)
        let lectureSource = LectureSourceDescriptor(id: 19, kind: .window, name: "Manual", width: 1800, height: 2400)
        let values: [ControlPacket] = [.hello(version: ProtocolVersion.current, channel: .control, client: "iPad", sessionID: id), .authorizationRequired, .authorizationResult(approved: true), .ping(id:id, sentAt:1), .pong(id:id, sentAt:1), .videoAcknowledgement(streamID: id, sequence: 7, requiresKeyframe: false), .displays([display]), .display(display), .selectDisplay(id: display.id), .requestLectureSourceSelection(requestID: id), .lectureSourceSelected(lectureSource, generation: id), .lectureSourceUnavailable(reason: .closed, generation: id), .leaveLectureMode, .strokeBegin(id:id, style:.defaultPen, point:point), .strokePoints(id:id, points:[point]), .strokeEnd(id:id), .deleteStrokes(ids:[id]), .clear]
        for value in values { #expect(try JSONDecoder().decode(ControlPacket.self, from: JSONEncoder().encode(value)) == value) }
    }
    @Test func lectureProtocolUsesVersionSevenAndRejectsUnboundedMetadata() throws {
        #expect(ProtocolVersion.current == 7)
        let source = LectureSourceDescriptor(id: 1, kind: .window, name: "Manual", width: 1200, height: 1600)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        object["name"] = String(repeating: "x", count: 300)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LectureSourceDescriptor.self, from: JSONSerialization.data(withJSONObject: object))
        }
        object["name"] = "Manual"
        object["width"] = 100_000
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LectureSourceDescriptor.self, from: JSONSerialization.data(withJSONObject: object))
        }
    }
    @Test func videoEnvelopeRoundTripAndTruncation() throws {
        let header = VideoFrameHeader(streamID: UUID(), sequence: 9, presentationTime: 42.5, isKeyframe: true)
        let bytes = Data([1, 2, 3, 4])
        let decoded = try VideoEnvelope.decode(VideoEnvelope.encode(header: header, accessUnit: bytes))
        #expect(decoded.0 == header); #expect(decoded.1 == bytes)
        #expect(throws: VideoEnvelopeError.self) { try VideoEnvelope.decode(Data([0, 0, 0])) }
    }
}
