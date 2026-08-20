import CoreGraphics

/// User-adjustable pointer response. Values are clamped here so neither restored
/// preferences nor future UI changes can create an unusable motion curve.
struct TrackpadMotionSettings: Sendable, Equatable {
    static let sensitivityRange: ClosedRange<CGFloat> = 0.5...2.0
    static let speedRange: ClosedRange<CGFloat> = 0.5...2.5

    let sensitivity: CGFloat
    let speed: CGFloat
    let accelerationEnabled: Bool

    init(sensitivity: CGFloat = 1, speed: CGFloat = 1.35, accelerationEnabled: Bool = true) {
        self.sensitivity = sensitivity.clamped(to: Self.sensitivityRange)
        self.speed = speed.clamped(to: Self.speedRange)
        self.accelerationEnabled = accelerationEnabled
    }
}

/// Pure motion curve shared by the UIKit surface and unit tests.
enum TrackpadMotionTransformer {
    static func transform(delta: CGPoint, settings: TrackpadMotionSettings) -> CGPoint {
        let magnitude = hypot(delta.x, delta.y)
        let acceleration: CGFloat
        if settings.accelerationEnabled {
            // Slow movements stay precise; increasingly fast gestures gain up to
            // 2.5× additional travel without discontinuities.
            acceleration = 1 + min(max(0, magnitude - 2) / 18, 1.5)
        } else {
            acceleration = 1
        }
        let scale = settings.sensitivity * settings.speed * acceleration
        return CGPoint(x: delta.x * scale, y: delta.y * scale)
    }
}

/// Tracks the pointer position Skeldri has commanded, rather than re-reading the
/// system cursor for every event.
///
/// Synthetic Quartz events are applied asynchronously, so reading the system
/// location immediately after posting a move usually still returns the previous
/// position. Deriving the next move from that stale read loses movement, and
/// posting a click at it lands the click wherever the pointer was a moment
/// earlier — on a dense target like the Dock, that is a different icon.
///
/// The commanded position is abandoned once the window server has certainly
/// caught up and the system disagrees, which is how a physical mouse moving the
/// same pointer is picked back up.
struct TrackpadCursorTracker: Sendable, Equatable {
    /// After this long, our last move has certainly been applied, so a differing
    /// system location means something other than Skeldri moved the pointer.
    static let resynchronizeAfter: Double = 0.25
    static let resynchronizeDistance: CGFloat = 2

    private var commanded: CGPoint?
    private var lastCommandTime = -Double.greatestFiniteMagnitude

    mutating func nextLocation(systemLocation: CGPoint, deltaX: CGFloat, deltaY: CGFloat,
                               bounds: CGRect, now: Double) -> CGPoint {
        let origin = base(systemLocation: systemLocation, now: now)
        let moved = CGPoint(x: origin.x + deltaX, y: origin.y + deltaY)
        let destination = bounds.isNull || bounds.isEmpty ? moved : clamp(moved, to: bounds)
        commanded = destination
        lastCommandTime = now
        return destination
    }

    /// Where a button event belongs. Reading does not extend the trust window.
    mutating func currentLocation(systemLocation: CGPoint, now: Double) -> CGPoint {
        let location = base(systemLocation: systemLocation, now: now)
        commanded = location
        return location
    }

    mutating func invalidate() {
        commanded = nil
        lastCommandTime = -Double.greatestFiniteMagnitude
    }

    private mutating func base(systemLocation: CGPoint, now: Double) -> CGPoint {
        guard let commanded else { return systemLocation }
        guard now - lastCommandTime > Self.resynchronizeAfter else { return commanded }
        let drift = hypot(systemLocation.x - commanded.x, systemLocation.y - commanded.y)
        return drift > Self.resynchronizeDistance ? systemLocation : commanded
    }

    private func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(
            x: point.x.clamped(to: bounds.minX...max(bounds.minX, bounds.maxX - 1)),
            y: point.y.clamped(to: bounds.minY...max(bounds.minY, bounds.maxY - 1))
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
