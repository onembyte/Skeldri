import CoreGraphics
import Foundation
import Testing

struct TrackpadCursorTrackerTests {
    private let desktop = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test func aClickLandsWhereTheLastMoveWentNotWhereTheSystemStillReports() {
        var tracker = TrackpadCursorTracker()

        let moved = tracker.nextLocation(
            systemLocation: CGPoint(x: 100, y: 100), deltaX: 60, deltaY: 0, bounds: desktop, now: 1
        )
        #expect(moved == CGPoint(x: 160, y: 100))

        // The window server has not applied the move yet, so the system still
        // reports the old position. The click must not go there.
        let clickLocation = tracker.currentLocation(systemLocation: CGPoint(x: 100, y: 100), now: 1.01)
        #expect(clickLocation == CGPoint(x: 160, y: 100))
    }

    @Test func consecutiveMovesAccumulateInsteadOfRestartingFromAStaleRead() {
        var tracker = TrackpadCursorTracker()
        var location = CGPoint(x: 500, y: 500)

        for step in 1...5 {
            location = tracker.nextLocation(
                // The system read lags a whole gesture behind.
                systemLocation: CGPoint(x: 500, y: 500),
                deltaX: 10, deltaY: 5, bounds: desktop, now: 1 + Double(step) * 0.01
            )
        }

        #expect(location == CGPoint(x: 550, y: 525))
    }

    @Test func aPhysicalMouseMoveIsAdoptedOnceTheServerHasCaughtUp() {
        var tracker = TrackpadCursorTracker()
        _ = tracker.nextLocation(
            systemLocation: CGPoint(x: 100, y: 100), deltaX: 10, deltaY: 10, bounds: desktop, now: 1
        )

        // Well past the settle window, and the pointer is somewhere else: the
        // user moved it with a real mouse, so relative motion resumes from there.
        let resumed = tracker.nextLocation(
            systemLocation: CGPoint(x: 800, y: 400), deltaX: 5, deltaY: 0,
            bounds: desktop, now: 1 + TrackpadCursorTracker.resynchronizeAfter + 0.1
        )
        #expect(resumed == CGPoint(x: 805, y: 400))
    }

    @Test func movementIsClampedInsideTheDesktopSoTrackingCannotDriftOffscreen() {
        var tracker = TrackpadCursorTracker()

        let farRight = tracker.nextLocation(
            systemLocation: CGPoint(x: 1900, y: 1070), deltaX: 5_000, deltaY: 5_000,
            bounds: desktop, now: 1
        )
        #expect(farRight == CGPoint(x: 1919, y: 1079))

        let farLeft = tracker.nextLocation(
            systemLocation: CGPoint(x: 10, y: 10), deltaX: -5_000, deltaY: -5_000,
            bounds: desktop, now: 1.01
        )
        #expect(farLeft == CGPoint(x: 0, y: 0))
    }

    @Test func invalidateFallsBackToTheSystemPointer() {
        var tracker = TrackpadCursorTracker()
        _ = tracker.nextLocation(
            systemLocation: CGPoint(x: 100, y: 100), deltaX: 50, deltaY: 50, bounds: desktop, now: 1
        )

        tracker.invalidate()

        // Entering Trackpad mode again must not resume from a stale session.
        let afterReset = tracker.currentLocation(systemLocation: CGPoint(x: 700, y: 300), now: 1.01)
        #expect(afterReset == CGPoint(x: 700, y: 300))
    }
}
