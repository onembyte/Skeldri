import Foundation

enum TrackpadButton: String, Codable, Sendable, Equatable {
    case left
    case right
}

/// Relative pointer input sent over the low-bandwidth control channel.
enum TrackpadEvent: Codable, Sendable, Equatable {
    case move(sequence: UInt64, deltaX: Float, deltaY: Float)
    case scroll(sequence: UInt64, deltaX: Float, deltaY: Float)
    case magnify(sequence: UInt64, delta: Float)
    case button(sequence: UInt64, button: TrackpadButton, isDown: Bool, clickCount: Int)
    case reset(sequence: UInt64)

    var sequence: UInt64 {
        switch self {
        case let .move(sequence, _, _), let .scroll(sequence, _, _), let .magnify(sequence, _),
             let .button(sequence, _, _, _), let .reset(sequence): sequence
        }
    }
}

/// Validation boundary for network-delivered pointer data.
enum TrackpadInputValidator {
    static let maximumDelta: Float = 500

    static func validated(_ event: TrackpadEvent) -> TrackpadEvent? {
        switch event {
        case let .move(sequence, deltaX, deltaY):
            guard deltaX.isFinite, deltaY.isFinite else { return nil }
            return .move(sequence: sequence, deltaX: clamp(deltaX), deltaY: clamp(deltaY))
        case let .scroll(sequence, deltaX, deltaY):
            guard deltaX.isFinite, deltaY.isFinite else { return nil }
            return .scroll(sequence: sequence, deltaX: clamp(deltaX), deltaY: clamp(deltaY))
        case let .magnify(sequence, delta):
            guard delta.isFinite else { return nil }
            return .magnify(sequence: sequence, delta: min(1, max(-1, delta)))
        case let .button(sequence, button, isDown, clickCount):
            return .button(sequence: sequence, button: button, isDown: isDown,
                           clickCount: min(3, max(1, clickCount)))
        case .reset:
            return event
        }
    }

    private static func clamp(_ value: Float) -> Float {
        min(maximumDelta, max(-maximumDelta, value))
    }
}

/// Normalizes UIKit tap counters into the click states understood by macOS.
enum TrackpadGesturePolicy {
    static func clickCount(from tapCount: Int) -> Int {
        min(3, max(1, tapCount))
    }
}

enum TrackpadTwoFingerIntent: Sendable, Equatable {
    case scroll
    case magnify
}

/// Resolves a two-finger gesture from accumulated geometry instead of racing
/// per-frame thresholds. A scroll primarily translates the fingers' centroid;
/// a pinch primarily changes the distance between them. Once resolved, intent
/// remains locked until every finger is lifted so one gesture cannot emit both
/// scroll and zoom events.
struct TrackpadTwoFingerClassifier: Sendable {
    private let minimumEvidence: Float
    private let dominanceRatio: Float
    private var centroidTravel: Float = 0
    private var signedSpanChange: Float = 0
    private(set) var intent: TrackpadTwoFingerIntent?

    init(minimumEvidence: Float = 5, dominanceRatio: Float = 1.25) {
        self.minimumEvidence = max(1, minimumEvidence)
        self.dominanceRatio = max(1.05, dominanceRatio)
    }

    mutating func update(centroidTravel: Float, spanChange: Float) -> TrackpadTwoFingerIntent? {
        guard intent == nil, centroidTravel.isFinite, spanChange.isFinite else { return intent }
        self.centroidTravel += abs(centroidTravel)
        signedSpanChange += spanChange

        let spanTravel = abs(signedSpanChange)
        if spanTravel >= minimumEvidence, spanTravel > self.centroidTravel * dominanceRatio {
            intent = .magnify
        } else if self.centroidTravel >= minimumEvidence,
                  self.centroidTravel > spanTravel * dominanceRatio {
            intent = .scroll
        }
        return intent
    }

    mutating func reset() {
        centroidTravel = 0
        signedSpanChange = 0
        intent = nil
    }
}

struct TrackpadScrollStep: Sendable, Equatable {
    static let zero = TrackpadScrollStep(vertical: 0, horizontal: 0)

    let vertical: Int32
    let horizontal: Int32
}

/// Retains fractional scroll movement between network events. Without this,
/// slow two-finger gestures can disappear when each small delta is rounded.
struct TrackpadScrollAccumulator: Sendable {
    private var verticalRemainder: Float = 0
    private var horizontalRemainder: Float = 0

    mutating func consume(deltaX: Float, deltaY: Float) -> TrackpadScrollStep {
        verticalRemainder += deltaY
        horizontalRemainder += deltaX
        let vertical = Int32(verticalRemainder.rounded()).clamped(to: -500...500)
        let horizontal = Int32(horizontalRemainder.rounded()).clamped(to: -500...500)
        verticalRemainder -= Float(vertical)
        horizontalRemainder -= Float(horizontal)
        return TrackpadScrollStep(vertical: vertical, horizontal: horizontal)
    }

    mutating func reset() {
        verticalRemainder = 0
        horizontalRemainder = 0
    }
}

/// Converts small continuous pinch changes into conventional desktop zoom
/// steps without losing sub-threshold movement between network packets.
struct TrackpadMagnifyAccumulator: Sendable {
    private let stepThreshold: Float
    private var remainder: Float = 0

    init(stepThreshold: Float = 0.08) {
        self.stepThreshold = max(0.01, stepThreshold)
    }

    mutating func consume(delta: Float) -> Int {
        remainder += delta
        let steps = Int(remainder / stepThreshold).clamped(to: -8...8)
        remainder -= Float(steps) * stepThreshold
        return steps
    }

    mutating func reset() {
        remainder = 0
    }
}

/// Rejects replayed and out-of-order remote input.
struct TrackpadSequenceGate: Sendable {
    private var lastSequence: UInt64?

    mutating func accepts(_ sequence: UInt64) -> Bool {
        guard lastSequence.map({ sequence > $0 }) ?? true else { return false }
        lastSequence = sequence
        return true
    }

    mutating func reset() {
        lastSequence = nil
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
