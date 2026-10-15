import Foundation

enum LectureSessionState: Sendable, Equatable {
    case inactive
    case selectingSource(requestID: UUID, previousSource: LectureSourceDescriptor?)
    case active(source: LectureSourceDescriptor, generation: UUID)
    case sourceUnavailable(source: LectureSourceDescriptor?, reason: LectureSourceUnavailableReason)
    case disconnected(lastSource: LectureSourceDescriptor?)
}

enum LectureSessionAction: Sendable, Equatable {
    case enter(requestID: UUID)
    case sourceSelected(LectureSourceDescriptor, generation: UUID)
    case sourceUnavailable(LectureSourceUnavailableReason, generation: UUID)
    case disconnected
    case leave
}

/// Deterministic state reducer shared by transport and presentation adapters.
/// Generation checks prevent a delayed failure from an obsolete capture source
/// replacing a newer, working Lecture session.
struct LectureSession: Sendable, Equatable {
    private(set) var state: LectureSessionState = .inactive

    @discardableResult
    mutating func apply(_ action: LectureSessionAction) -> Bool {
        let previousState = state
        switch action {
        case let .enter(requestID):
            state = .selectingSource(requestID: requestID, previousSource: currentSource)
        case let .sourceSelected(source, generation):
            guard acceptsResponse(generation: generation) else { return false }
            state = .active(source: source, generation: generation)
        case let .sourceUnavailable(reason, generation):
            guard acceptsResponse(generation: generation) else { return false }
            state = .sourceUnavailable(source: currentSource, reason: reason)
        case .disconnected:
            state = .disconnected(lastSource: currentSource)
        case .leave:
            state = .inactive
        }
        return state != previousState
    }

    private var currentSource: LectureSourceDescriptor? {
        switch state {
        case let .selectingSource(_, source): source
        case let .active(source, _): source
        case let .sourceUnavailable(source, _): source
        case let .disconnected(source): source
        case .inactive: nil
        }
    }

    private func acceptsResponse(generation: UUID) -> Bool {
        switch state {
        case let .selectingSource(requestID, _): requestID == generation
        case let .active(_, currentGeneration): currentGeneration == generation
        case .inactive, .sourceUnavailable, .disconnected: false
        }
    }
}
