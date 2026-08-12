import UIKit

/// Full-screen relative pointing surface. Drawing and pointer input use separate
/// UIView instances so toolbar/navigation touches can never leak into either mode.
final class TrackpadUIView: UIView {
    var motionSettings = TrackpadMotionSettings()
    var onMove: ((CGFloat, CGFloat) -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?
    var onMagnify: ((CGFloat) -> Void)?
    var onButton: ((TrackpadButton, Bool, Int) -> Void)?

    private var gestureTouchCount = 0
    private var gestureStartedAt: TimeInterval = 0
    private var lastCentroid: CGPoint?
    private var totalMovement: CGFloat = 0
    private var dragging = false
    private var lastTwoFingerDistance: CGFloat?
    private var twoFingerGesture = TwoFingerGesture.undecided

    private enum TwoFingerGesture { case undecided, scroll, magnify }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isOpaque = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let active = activeTouches(in: event)
        guard !active.isEmpty else { return }
        if dragging, active.count != 1 { endDrag() }
        gestureTouchCount = active.count
        gestureStartedAt = active.map(\.timestamp).min() ?? ProcessInfo.processInfo.systemUptime
        lastCentroid = centroid(of: active)
        lastTwoFingerDistance = active.count == 2 ? distance(between: active) : nil
        twoFingerGesture = .undecided
        totalMovement = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let active = activeTouches(in: event)
        guard active.count == gestureTouchCount,
              let current = centroid(of: active), let previous = lastCentroid else { return }
        let delta = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
        lastCentroid = current
        let previousMovement = totalMovement
        totalMovement += hypot(delta.x, delta.y)

        switch active.count {
        case 1:
            let elapsed = (active.first?.timestamp ?? 0) - gestureStartedAt
            if !dragging, elapsed >= 0.35, previousMovement < 12 {
                dragging = true
                onButton?(.left, true, 1)
            }
            let transformed = TrackpadMotionTransformer.transform(delta: delta, settings: motionSettings)
            onMove?(transformed.x, transformed.y)
        case 2:
            let currentDistance = distance(between: active)
            let relativeDistanceChange = lastTwoFingerDistance.flatMap { previous in
                previous > 0 ? (currentDistance - previous) / previous : nil
            } ?? 0
            lastTwoFingerDistance = currentDistance

            if twoFingerGesture == .undecided {
                if abs(relativeDistanceChange) >= 0.012 {
                    twoFingerGesture = .magnify
                } else if hypot(delta.x, delta.y) >= 2.5 {
                    twoFingerGesture = .scroll
                }
            }
            switch twoFingerGesture {
            case .magnify: onMagnify?(relativeDistanceChange)
            case .scroll: onScroll?(delta.x, delta.y)
            case .undecided: break
            }
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouches(in: event).isEmpty else { return }
        let duration = (touches.map(\.timestamp).max() ?? gestureStartedAt) - gestureStartedAt
        if dragging {
            endDrag()
        } else if totalMovement < 10, duration < 0.35, twoFingerGesture == .undecided {
            if gestureTouchCount == 1 {
                let clickCount = TrackpadGesturePolicy.clickCount(from: touches.first?.tapCount ?? 1)
                click(.left, count: clickCount)
            } else if gestureTouchCount == 2 {
                click(.right, count: 1)
            }
        }
        resetGesture()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag()
        resetGesture()
    }

    private func click(_ button: TrackpadButton, count: Int) {
        onButton?(button, true, count)
        onButton?(button, false, count)
    }

    private func endDrag() {
        guard dragging else { return }
        dragging = false
        onButton?(.left, false, 1)
    }

    private func resetGesture() {
        gestureTouchCount = 0
        lastCentroid = nil
        totalMovement = 0
        lastTwoFingerDistance = nil
        twoFingerGesture = .undecided
    }

    private func activeTouches(in event: UIEvent?) -> [UITouch] {
        (event?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled }
    }

    private func centroid(of touches: [UITouch]) -> CGPoint? {
        guard !touches.isEmpty else { return nil }
        let total = touches.reduce(CGPoint.zero) { partial, touch in
            let point = touch.location(in: self)
            return CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        return CGPoint(x: total.x / CGFloat(touches.count), y: total.y / CGFloat(touches.count))
    }

    private func distance(between touches: [UITouch]) -> CGFloat {
        guard touches.count == 2 else { return 0 }
        let first = touches[0].location(in: self)
        let second = touches[1].location(in: self)
        return hypot(second.x - first.x, second.y - first.y)
    }
}
