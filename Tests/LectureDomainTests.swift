import Foundation
import Testing

struct LectureDomainTests {
    @Test func experienceModeIncludesReadOnlyLecture() throws {
        let encoded = try JSONEncoder().encode(SkeldriInputMode.lecture)
        #expect(try JSONDecoder().decode(SkeldriInputMode.self, from: encoded) == .lecture)
        #expect(ExperienceModeTransition(from: .trackpad, to: .lecture).mustResetTrackpad)
        #expect(!ExperienceModeTransition(from: .drawing, to: .lecture).mustResetTrackpad)
    }

    @Test func sessionTransitionsAreExplicitAndRetainTheLastSourceOnDisconnect() {
        let source = LectureSourceDescriptor(
            id: 42,
            kind: .window,
            name: "Reference Manual",
            width: 1800,
            height: 2400
        )
        let generation = UUID()
        var session = LectureSession()

        session.apply(.enter(requestID: generation))
        #expect(session.state == .selectingSource(requestID: generation, previousSource: nil))
        session.apply(.sourceSelected(source, generation: generation))
        #expect(session.state == .active(source: source, generation: generation))
        session.apply(.disconnected)
        #expect(session.state == .disconnected(lastSource: source))
        session.apply(.leave)
        #expect(session.state == .inactive)
    }

    @Test func staleSourceFailuresCannotReplaceAReplacementGeneration() {
        let source = LectureSourceDescriptor(id: 9, kind: .display, name: "Display 1", width: 1600, height: 1000)
        let oldGeneration = UUID()
        let currentGeneration = UUID()
        var session = LectureSession()

        session.apply(.enter(requestID: oldGeneration))
        session.apply(.sourceSelected(source, generation: oldGeneration))
        session.apply(.enter(requestID: currentGeneration))
        session.apply(.sourceUnavailable(.closed, generation: oldGeneration))

        #expect(session.state == .selectingSource(requestID: currentGeneration, previousSource: source))
        session.apply(.sourceSelected(source, generation: currentGeneration))
        session.apply(.sourceUnavailable(.closed, generation: currentGeneration))
        #expect(session.state == .sourceUnavailable(source: source, reason: .closed))
    }

    @Test func uncorrelatedResponsesCannotDisturbAnIdleOrAbandonedSession() {
        let source = LectureSourceDescriptor(id: 3, kind: .window, name: "Slides", width: 1440, height: 900)
        let request = UUID()
        var session = LectureSession()

        // A failure matching no outstanding request is ignored while inactive.
        let strayFailure = session.apply(.sourceUnavailable(.captureFailed, generation: UUID()))
        #expect(!strayFailure)
        #expect(session.state == .inactive)

        session.apply(.enter(requestID: request))

        // A response carrying a foreign request cannot resolve the outstanding one.
        let foreignResponse = session.apply(.sourceSelected(source, generation: UUID()))
        #expect(!foreignResponse)
        #expect(session.state == .selectingSource(requestID: request, previousSource: nil))

        // Leaving Lecture invalidates the outstanding request, so a late Mac
        // response can never silently resume presenting captured content.
        session.apply(.leave)
        let lateResponse = session.apply(.sourceSelected(source, generation: request))
        #expect(!lateResponse)
        #expect(session.state == .inactive)
    }

    @Test func repeatedIdenticalSelectionReportsNoChange() {
        let source = LectureSourceDescriptor(id: 4, kind: .display, name: "Display 2", width: 2560, height: 1440)
        let generation = UUID()
        var session = LectureSession()

        session.apply(.enter(requestID: generation))
        let firstSelection = session.apply(.sourceSelected(source, generation: generation))
        #expect(firstSelection)
        // Re-announcing the same source must not restart the decoder or viewport.
        let duplicateSelection = session.apply(.sourceSelected(source, generation: generation))
        #expect(!duplicateSelection)
        #expect(session.state == .active(source: source, generation: generation))
    }

    @Test func navigationPolicyCombinesDeadZoneAccelerationAndPrecision() {
        let policy = LectureNavigationPolicy()

        #expect(policy.velocity(verticalDisplacement: 0.05, horizontalDistance: 0) == 0)
        let precise = policy.velocity(verticalDisplacement: 0.8, horizontalDistance: 220)
        let fast = policy.velocity(verticalDisplacement: 0.8, horizontalDistance: 0)
        #expect(fast > precise)
        #expect(precise > 0)
        #expect(policy.velocity(verticalDisplacement: -0.8, horizontalDistance: 0) == -fast)
    }

    @Test func navigationIntegrationClampsAndSupportsAccessibilitySteps() {
        let policy = LectureNavigationPolicy(accessibilityStep: 0.1)

        #expect(policy.integrate(position: 0.95, velocity: 1, elapsed: 1) == 1)
        #expect(policy.integrate(position: 0.05, velocity: -1, elapsed: 1) == 0)
        #expect(policy.accessibilityPosition(from: 0.5, direction: .increment) == 0.6)
        #expect(policy.accessibilityPosition(from: 0.05, direction: .decrement) == 0)
    }
}
