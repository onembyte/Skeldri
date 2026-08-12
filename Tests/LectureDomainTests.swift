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

        session.apply(.enter)
        #expect(session.state == .selectingSource)
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

        session.apply(.enter)
        session.apply(.sourceSelected(source, generation: oldGeneration))
        session.apply(.sourceSelected(source, generation: currentGeneration))
        session.apply(.sourceUnavailable(.closed, generation: oldGeneration))

        #expect(session.state == .active(source: source, generation: currentGeneration))
        session.apply(.sourceUnavailable(.closed, generation: currentGeneration))
        #expect(session.state == .sourceUnavailable(source: source, reason: .closed))
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
