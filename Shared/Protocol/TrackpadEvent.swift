import Foundation

enum TrackpadButton: String, Codable, Sendable, Equatable {
    case left
    case right
}

/// Relative pointer input sent over the low-bandwidth control channel.
enum TrackpadEvent: Codable, Sendable, Equatable {
    case move(sequence: UInt64, deltaX: Float, deltaY: Float)
    case scroll(sequence: UInt64, deltaX: Float, deltaY: Float)
    case button(sequence: UInt64, button: TrackpadButton, isDown: Bool, clickCount: Int)
    case reset(sequence: UInt64)

    var sequence: UInt64 {
        switch self {
        case let .move(sequence, _, _), let .scroll(sequence, _, _),
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
