import Foundation

/// Suppresses repeated SPS/PPS packets for periodic keyframes while ensuring a
/// new encoder generation or connection receives its format exactly once.
struct VideoConfigurationGate: Sendable {
    private var configuredStreamID: UUID?

    mutating func shouldSend(streamID: UUID) -> Bool {
        guard configuredStreamID != streamID else { return false }
        configuredStreamID = streamID
        return true
    }

    mutating func reset() {
        configuredStreamID = nil
    }
}

/// A small application-level send window that bounds video data beyond the
/// operating system's TCP buffers. The owner must serialize mutations.
struct VideoSendWindow: Sendable {
    private let maximumOutstandingFrames: Int
    private var activeStreamID: UUID?
    private var outstandingSequences: Set<UInt64> = []

    init(maximumOutstandingFrames: Int) {
        precondition(maximumOutstandingFrames > 0)
        self.maximumOutstandingFrames = maximumOutstandingFrames
    }

    mutating func begin(streamID: UUID) {
        guard streamID != activeStreamID else { return }
        activeStreamID = streamID
        outstandingSequences.removeAll(keepingCapacity: true)
    }

    mutating func reserve(streamID: UUID, sequence: UInt64) -> Bool {
        guard streamID == activeStreamID,
              outstandingSequences.count < maximumOutstandingFrames,
              !outstandingSequences.contains(sequence) else { return false }
        outstandingSequences.insert(sequence)
        return true
    }

    mutating func acknowledge(streamID: UUID, through sequence: UInt64) {
        guard streamID == activeStreamID else { return }
        outstandingSequences = outstandingSequences.filter { $0 > sequence }
    }

    mutating func reset() {
        activeStreamID = nil
        outstandingSequences.removeAll(keepingCapacity: true)
    }
}

enum VideoSequenceDecision: Sendable, Equatable {
    case accept
    case discard
    case requestKeyframe
}

/// Protects an H.264 decoder from missing reference pictures. After a sequence
/// gap, only a keyframe may resume decoding.
struct VideoSequenceGate: Sendable {
    private var activeStreamID: UUID?
    private var lastAcceptedSequence: UInt64?
    private var waitingForKeyframe = true

    mutating func configure(streamID: UUID) {
        guard streamID != activeStreamID else { return }
        activeStreamID = streamID
        lastAcceptedSequence = nil
        waitingForKeyframe = true
    }

    mutating func evaluate(streamID: UUID, sequence: UInt64, isKeyframe: Bool) -> VideoSequenceDecision {
        guard streamID == activeStreamID else { return .discard }
        if let lastAcceptedSequence, sequence <= lastAcceptedSequence { return .discard }

        if waitingForKeyframe {
            guard isKeyframe else { return .requestKeyframe }
        } else if let lastAcceptedSequence, sequence != lastAcceptedSequence + 1 {
            waitingForKeyframe = true
            guard isKeyframe else { return .requestKeyframe }
        }

        waitingForKeyframe = false
        lastAcceptedSequence = sequence
        return .accept
    }

    mutating func requireKeyframe() {
        waitingForKeyframe = true
    }

    mutating func reset() {
        activeStreamID = nil
        lastAcceptedSequence = nil
        waitingForKeyframe = true
    }
}
