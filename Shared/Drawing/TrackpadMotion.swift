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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
