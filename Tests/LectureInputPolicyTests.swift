import Foundation
import Testing

struct LectureInputPolicyTests {
    private let point = StrokePoint(x: 0.5, y: 0.5, timestamp: 1, pressure: 1)

    private var mutatingPackets: [ControlPacket] {
        let id = UUID()
        return [
            .strokeBegin(id: id, style: .defaultPen, point: point),
            .strokePoints(id: id, points: [point]),
            .strokeEnd(id: id),
            .deleteStrokes(ids: [id]),
            .clear,
            .canvasSnapshot([]),
            .trackpad(.move(sequence: 1, deltaX: 4, deltaY: 4)),
            .trackpad(.scroll(sequence: 2, deltaX: 0, deltaY: 12)),
            .trackpad(.magnify(sequence: 3, delta: 0.2)),
            .trackpad(.button(sequence: 4, button: .left, isDown: true, clickCount: 1))
        ]
    }

    @Test func readModeRefusesEveryDrawingAndPointerMutation() {
        for packet in mutatingPackets {
            #expect(!LectureInputPolicy.allows(packet, whileIn: .lecture))
        }
    }

    @Test func readModeStillAllowsTheTrackpadReleaseFailSafe() {
        // Leaving Trackpad for Read sends a reset. Refusing it would strand a
        // held mouse button down on the Mac.
        #expect(LectureInputPolicy.allows(.trackpad(.reset(sequence: 9)), whileIn: .lecture))
    }

    @Test func readModeAllowsNonMutatingSessionTraffic() {
        let id = UUID()
        let allowed: [ControlPacket] = [
            .ping(id: id, sentAt: 1),
            .pong(id: id, sentAt: 1),
            .videoAcknowledgement(streamID: id, sequence: 3, requiresKeyframe: false),
            .inputMode(.drawing),
            .requestLectureSourceSelection(requestID: id),
            .leaveLectureMode
        ]
        for packet in allowed {
            #expect(LectureInputPolicy.allows(packet, whileIn: .lecture))
        }
    }

    @Test func drawAndTrackpadModesAreLeftUnconstrained() {
        for packet in mutatingPackets {
            #expect(LectureInputPolicy.allows(packet, whileIn: .drawing))
            #expect(LectureInputPolicy.allows(packet, whileIn: .trackpad))
        }
    }
}
