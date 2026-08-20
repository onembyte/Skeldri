import CoreGraphics
import Testing

@Suite struct TrackpadMotionTests {
    @Test func sensitivityAndSpeedScaleMovementIndependently() {
        let settings = TrackpadMotionSettings(sensitivity: 1.5, speed: 2, accelerationEnabled: false)
        let result = TrackpadMotionTransformer.transform(delta: CGPoint(x: 2, y: -3), settings: settings)

        #expect(result.x == 6)
        #expect(result.y == -9)
    }

    @Test func accelerationPreservesDirectionAndAmplifiesFastMovement() {
        let settings = TrackpadMotionSettings(sensitivity: 1, speed: 1, accelerationEnabled: true)
        let slow = TrackpadMotionTransformer.transform(delta: CGPoint(x: 1, y: 0), settings: settings)
        let fast = TrackpadMotionTransformer.transform(delta: CGPoint(x: 12, y: 0), settings: settings)

        #expect(slow.x >= 1)
        #expect(fast.x > 12)
        #expect(slow.y == 0)
        #expect(fast.y == 0)
    }

    @Test func settingsAreClampedAtTheInputBoundary() {
        let settings = TrackpadMotionSettings(sensitivity: -5, speed: 99, accelerationEnabled: false)

        #expect(settings.sensitivity == TrackpadMotionSettings.sensitivityRange.lowerBound)
        #expect(settings.speed == TrackpadMotionSettings.speedRange.upperBound)
    }
}
