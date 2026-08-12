import Foundation

enum LectureSessionState: Sendable, Equatable {
    case inactive
    case selectingSource
    case active(source: LectureSourceDescriptor, generation: UUID)
    case sourceUnavailable(source: LectureSourceDescriptor?, reason: LectureSourceUnavailableReason)
    case disconnected(lastSource: LectureSourceDescriptor?)
}

enum LectureSessionAction: Sendable, Equatable {
    case enter
    case sourceSelected(LectureSourceDescriptor, generation: UUID)
    case sourceUnavailable(LectureSourceUnavailableReason, generation: UUID?)
    case disconnected
    case leave
}

/// Deterministic state reducer shared by transport and presentation adapters.
/// Generation checks prevent a delayed failure from an obsolete capture source
/// replacing a newer, working Lecture session.
struct LectureSession: Sendable, Equatable {
    private(set) var state: LectureSessionState = .inactive

    mutating func apply(_ action: LectureSessionAction) {
        switch action {
        case .enter:
            state = .selectingSource
        case let .sourceSelected(source, generation):
            state = .active(source: source, generation: generation)
        case let .sourceUnavailable(reason, generation):
            guard generationMatchesCurrent(generation) else { return }
            state = .sourceUnavailable(source: currentSource, reason: reason)
        case .disconnected:
            state = .disconnected(lastSource: currentSource)
        case .leave:
            state = .inactive
        }
    }

    private var currentSource: LectureSourceDescriptor? {
        switch state {
        case let .active(source, _): source
        case let .sourceUnavailable(source, _): source
        case let .disconnected(source): source
        case .inactive, .selectingSource: nil
        }
    }

    private func generationMatchesCurrent(_ generation: UUID?) -> Bool {
        guard let generation else { return true }
        guard case let .active(_, currentGeneration) = state else { return false }
        return generation == currentGeneration
    }
}
