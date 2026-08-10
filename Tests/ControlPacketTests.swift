import Foundation
import Testing

struct ControlPacketTests {
    @Test func codableRoundTrips() throws {
        let id = UUID(), point = StrokePoint(x: 0.2, y: 0.3, timestamp: 1, pressure: 1)
        let values: [ControlPacket] = [.hello(version: 1, channel: .control, client: "iPad"), .ping(id:id, sentAt:1), .pong(id:id, sentAt:1), .strokeBegin(id:id, style:.defaultPen, point:point), .strokePoints(id:id, points:[point]), .strokeEnd(id:id), .deleteStrokes(ids:[id]), .clear]
        for value in values { #expect(try JSONDecoder().decode(ControlPacket.self, from: JSONEncoder().encode(value)) == value) }
    }
}

