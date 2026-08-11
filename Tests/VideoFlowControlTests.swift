import Foundation
import Testing

struct VideoFlowControlTests {
    @Test func configurationIsSentOncePerGenerationAndAgainAfterReset() {
        let firstStream = UUID(), secondStream = UUID()
        var gate = VideoConfigurationGate()

        let first = gate.shouldSend(streamID: firstStream)
        let repeated = gate.shouldSend(streamID: firstStream)
        let changed = gate.shouldSend(streamID: secondStream)
        gate.reset()
        let reconnected = gate.shouldSend(streamID: secondStream)

        #expect(first)
        #expect(!repeated)
        #expect(changed)
        #expect(reconnected)
    }

    @Test func sendWindowBoundsOutstandingFramesAndReopensOnAcknowledgement() {
        let streamID = UUID()
        var window = VideoSendWindow(maximumOutstandingFrames: 2)

        window.begin(streamID: streamID)
        let first = window.reserve(streamID: streamID, sequence: 0)
        let second = window.reserve(streamID: streamID, sequence: 1)
        let overflow = window.reserve(streamID: streamID, sequence: 2)
        #expect(first)
        #expect(second)
        #expect(!overflow)

        window.acknowledge(streamID: streamID, through: 0)
        let reopened = window.reserve(streamID: streamID, sequence: 2)
        #expect(reopened)
    }

    @Test func sendWindowRejectsStaleStreamsAndResetsForNewGeneration() {
        let oldStream = UUID(), newStream = UUID()
        var window = VideoSendWindow(maximumOutstandingFrames: 1)

        window.begin(streamID: oldStream)
        let oldReserved = window.reserve(streamID: oldStream, sequence: 4)
        #expect(oldReserved)
        window.begin(streamID: newStream)
        window.acknowledge(streamID: oldStream, through: 4)

        let staleReserved = window.reserve(streamID: oldStream, sequence: 5)
        let newReserved = window.reserve(streamID: newStream, sequence: 0)
        #expect(!staleReserved)
        #expect(newReserved)
    }

    @Test func repeatedConfigurationDoesNotResetCurrentSendWindow() {
        let streamID = UUID()
        var window = VideoSendWindow(maximumOutstandingFrames: 1)

        window.begin(streamID: streamID)
        let first = window.reserve(streamID: streamID, sequence: 0)
        window.begin(streamID: streamID)
        let incorrectlyReopened = window.reserve(streamID: streamID, sequence: 1)

        #expect(first)
        #expect(!incorrectlyReopened)
    }

    @Test func sequenceGateRequiresKeyframeAfterGap() {
        let streamID = UUID()
        var gate = VideoSequenceGate()
        gate.configure(streamID: streamID)

        let first = gate.evaluate(streamID: streamID, sequence: 0, isKeyframe: true)
        let gap = gate.evaluate(streamID: streamID, sequence: 2, isKeyframe: false)
        let whileWaiting = gate.evaluate(streamID: streamID, sequence: 3, isKeyframe: false)
        let recovery = gate.evaluate(streamID: streamID, sequence: 4, isKeyframe: true)
        let resumed = gate.evaluate(streamID: streamID, sequence: 5, isKeyframe: false)
        #expect(first == .accept)
        #expect(gap == .requestKeyframe)
        #expect(whileWaiting == .requestKeyframe)
        #expect(recovery == .accept)
        #expect(resumed == .accept)
    }

    @Test func sequenceGateRejectsOldGenerationAndDuplicateFrames() {
        let streamID = UUID()
        var gate = VideoSequenceGate()
        gate.configure(streamID: streamID)

        let stale = gate.evaluate(streamID: UUID(), sequence: 0, isKeyframe: true)
        let first = gate.evaluate(streamID: streamID, sequence: 10, isKeyframe: true)
        let duplicate = gate.evaluate(streamID: streamID, sequence: 10, isKeyframe: true)
        #expect(stale == .discard)
        #expect(first == .accept)
        #expect(duplicate == .discard)
    }

    @Test func repeatedConfigurationDoesNotResetSequenceContinuity() {
        let streamID = UUID()
        var gate = VideoSequenceGate()
        gate.configure(streamID: streamID)
        let first = gate.evaluate(streamID: streamID, sequence: 4, isKeyframe: true)

        gate.configure(streamID: streamID)
        let duplicate = gate.evaluate(streamID: streamID, sequence: 4, isKeyframe: true)

        #expect(first == .accept)
        #expect(duplicate == .discard)
    }
}
