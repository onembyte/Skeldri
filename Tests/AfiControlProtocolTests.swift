import Foundation
import Testing

struct AfiControlProtocolTests {
    @Test func decodesLegacyHelloAndDrawingPackets() throws {
        let sessionID = UUID()
        let hello = try JSONSerialization.data(withJSONObject: [
            "protocolVersion": 1, "kind": "hello", "channel": "control", "client": "SkeldriAfi",
            "sessionID": sessionID.uuidString
        ])
        #expect(try AfiControlCodec.decode(hello) == .hello(version: 1, channel: .control, client: "SkeldriAfi", sessionID: sessionID))

        let id = UUID()
        let points = [StrokePoint(x: 0.25, y: 0.75, timestamp: 4, pressure: nil)]
        let object: [String: Any] = [
            "protocolVersion": 1, "kind": "strokePoints", "id": id.uuidString,
            "points": try JSONSerialization.jsonObject(with: JSONEncoder().encode(points))
        ]
        #expect(try AfiControlCodec.decode(JSONSerialization.data(withJSONObject: object)) ==
                .strokePoints(id: id, points: points))
    }

    @Test func rejectsIncompatibleUnknownAndMalformedPackets() throws {
        let future = try JSONSerialization.data(withJSONObject: ["protocolVersion": 2, "kind": "clear"])
        #expect(throws: AfiControlError.incompatibleVersion(2)) { try AfiControlCodec.decode(future) }
        let unknown = try JSONSerialization.data(withJSONObject: ["protocolVersion": 1, "kind": "shell"])
        #expect(throws: AfiControlError.unknownKind("shell")) { try AfiControlCodec.decode(unknown) }
        #expect(throws: AfiControlError.invalidEnvelope) { try AfiControlCodec.decode(Data("[]".utf8)) }
    }

    @Test func encodesMacAuthorityMessagesWithStableEnvelope() throws {
        let displays = [DisplayDescriptor(id: 7, name: "Studio", width: 1600, height: 1000)]
        let data = try AfiControlCodec.encode(.displays(displays))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["protocolVersion"] as? Int == 1)
        #expect(object["kind"] as? String == "displays")
        #expect((object["displays"] as? [[String: Any]])?.first?["id"] as? Int == 7)
    }

    @Test func decodesExactLegacyTrackpadEnvelopes() throws {
        let cases: [(String, [String: Any], TrackpadEvent)] = [
            ("move", ["sequence": 1, "deltaX": 3.5, "deltaY": -2.0],
             .move(sequence: 1, deltaX: 3.5, deltaY: -2)),
            ("scroll", ["sequence": 2, "deltaX": 0.5, "deltaY": 7.0],
             .scroll(sequence: 2, deltaX: 0.5, deltaY: 7)),
            ("magnify", ["sequence": 3, "delta": 0.12],
             .magnify(sequence: 3, delta: 0.12)),
            ("button", ["sequence": 4, "button": "left", "isDown": true, "clickCount": 2],
             .button(sequence: 4, button: .left, isDown: true, clickCount: 2)),
            ("reset", ["sequence": 5], .reset(sequence: 5))
        ]
        for (kind, payload, expected) in cases {
            let data = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1, "kind": "trackpad", "event": [kind: payload]
            ])
            #expect(try AfiControlCodec.decode(data) == .trackpad(expected))
        }
    }
}
