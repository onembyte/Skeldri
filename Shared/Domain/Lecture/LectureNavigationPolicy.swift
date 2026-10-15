import Foundation

enum LectureAccessibilityDirection: Sendable {
    case increment
    case decrement
}

/// Pure navigation math for the compact Lecture rail.
///
/// Displacement is normalized to `-1...1`. Motion starts outside the dead zone,
/// increases cubically for both reading precision and fast traversal, and slows
/// when the finger moves horizontally away from the rail.
struct LectureNavigationPolicy: Sendable, Equatable {
    let deadZone: Double
    let maximumTraversalRate: Double
    let precisionDistance: Double
    let minimumPrecisionGain: Double
    let accessibilityStep: Double

    init(
        deadZone: Double = 0.12,
        maximumTraversalRate: Double = 0.5,
        precisionDistance: Double = 220,
        minimumPrecisionGain: Double = 0.15,
        accessibilityStep: Double = 0.08
    ) {
        self.deadZone = deadZone.clamped(to: 0...0.95)
        self.maximumTraversalRate = max(0, maximumTraversalRate)
        self.precisionDistance = max(1, precisionDistance)
        self.minimumPrecisionGain = minimumPrecisionGain.clamped(to: 0...1)
        self.accessibilityStep = accessibilityStep.clamped(to: 0...1)
    }

    /// Returns normalized viewport positions per second.
    func velocity(verticalDisplacement: Double, horizontalDistance: Double) -> Double {
        guard verticalDisplacement.isFinite, horizontalDistance.isFinite else { return 0 }
        let signedDisplacement = verticalDisplacement.clamped(to: -1...1)
        let magnitude = abs(signedDisplacement)
        guard magnitude > deadZone else { return 0 }

        let activeRange = max(0.000_001, 1 - deadZone)
        let response = ((magnitude - deadZone) / activeRange).clamped(to: 0...1)
        let distanceFraction = (max(0, horizontalDistance) / precisionDistance).clamped(to: 0...1)
        let precisionGain = max(minimumPrecisionGain, 1 - distanceFraction * (1 - minimumPrecisionGain))
        let direction = signedDisplacement.sign == .minus ? -1.0 : 1.0
        return direction * response * response * response * maximumTraversalRate * precisionGain
    }

    func integrate(position: Double, velocity: Double, elapsed: Double) -> Double {
        let safePosition = position.isFinite ? position.clamped(to: 0...1) : 0
        guard velocity.isFinite, elapsed.isFinite, elapsed > 0 else { return safePosition }
        return (safePosition + velocity * elapsed).clamped(to: 0...1)
    }

    func accessibilityPosition(from position: Double, direction: LectureAccessibilityDirection) -> Double {
        let delta = direction == .increment ? accessibilityStep : -accessibilityStep
        return integrate(position: position, velocity: delta, elapsed: 1)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
