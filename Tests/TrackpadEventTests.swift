import Foundation
import Testing

struct TrackpadEventTests {
    @Test func eventsRoundTripThroughControlProtocol() throws {
        let events: [TrackpadEvent] = [
            .move(sequence: 1, deltaX: 12.5, deltaY: -4),
            .scroll(sequence: 2, deltaX: 0, deltaY: 18),
            .magnify(sequence: 3, delta: 0.12),
            .button(sequence: 4, button: .left, isDown: true, clickCount: 1),
            .button(sequence: 5, button: .right, isDown: false, clickCount: 1),
            .reset(sequence: 6)
        ]

        for event in events {
            let packet = ControlPacket.trackpad(event)
            let decoded = try JSONDecoder().decode(ControlPacket.self, from: JSONEncoder().encode(packet))
            #expect(decoded == packet)
        }
        let mode = ControlPacket.inputMode(.trackpad)
        #expect(try JSONDecoder().decode(ControlPacket.self, from: JSONEncoder().encode(mode)) == mode)
    }

    @Test func validatorRejectsNonFiniteAndClampsUntrustedDeltas() {
        #expect(TrackpadInputValidator.validated(.move(sequence: 1, deltaX: .nan, deltaY: 1)) == nil)
        #expect(TrackpadInputValidator.validated(.scroll(sequence: 2, deltaX: 1, deltaY: .infinity)) == nil)
        #expect(TrackpadInputValidator.validated(.magnify(sequence: 3, delta: .nan)) == nil)
        #expect(TrackpadInputValidator.validated(.move(sequence: 3, deltaX: 5_000, deltaY: -5_000)) ==
                .move(sequence: 3, deltaX: 500, deltaY: -500))
        #expect(TrackpadInputValidator.validated(.magnify(sequence: 4, delta: 20)) ==
                .magnify(sequence: 4, delta: 1))
        #expect(TrackpadInputValidator.validated(.button(sequence: 4, button: .left, isDown: true, clickCount: 99)) ==
                .button(sequence: 4, button: .left, isDown: true, clickCount: 3))
    }

    @Test func sequenceGateRejectsDuplicateAndOldInput() {
        var gate = TrackpadSequenceGate()
        let first = gate.accepts(10)
        let duplicate = gate.accepts(10)
        let old = gate.accepts(9)
        let next = gate.accepts(11)
        gate.reset()
        let afterReset = gate.accepts(0)
        #expect(first)
        #expect(!duplicate)
        #expect(!old)
        #expect(next)
        #expect(afterReset)
    }

    @Test func clickPolicySupportsNativeSingleDoubleAndTripleClickStates() {
        #expect(TrackpadGesturePolicy.clickCount(from: 0) == 1)
        #expect(TrackpadGesturePolicy.clickCount(from: 1) == 1)
        #expect(TrackpadGesturePolicy.clickCount(from: 2) == 2)
        #expect(TrackpadGesturePolicy.clickCount(from: 3) == 3)
        #expect(TrackpadGesturePolicy.clickCount(from: 8) == 3)
    }

    @Test func scrollAccumulatorPreservesSubpixelTwoFingerMovement() {
        var accumulator = TrackpadScrollAccumulator()
        let first = accumulator.consume(deltaX: 0.2, deltaY: 0.2)
        let second = accumulator.consume(deltaX: 0.2, deltaY: 0.2)
        let third = accumulator.consume(deltaX: 0.2, deltaY: 0.2)

        #expect(first == .zero)
        #expect(second == .zero)
        #expect(third.vertical == 1)
        #expect(third.horizontal == 1)
    }

    @Test func magnifyAccumulatorProducesStableDiscreteZoomSteps() {
        var accumulator = TrackpadMagnifyAccumulator(stepThreshold: 0.1)

        #expect(accumulator.consume(delta: 0.04) == 0)
        #expect(accumulator.consume(delta: 0.04) == 0)
        #expect(accumulator.consume(delta: 0.04) == 1)
        #expect(accumulator.consume(delta: -0.25) == -2)
        accumulator.reset()
        #expect(accumulator.consume(delta: 0.09) == 0)
    }
}
