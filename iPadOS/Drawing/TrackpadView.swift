import UIKit

/// Full-screen relative pointing surface. Drawing and pointer input use separate
/// UIView instances so toolbar/navigation touches can never leak into either mode.
final class TrackpadUIView: UIView {
    var motionSettings = TrackpadMotionSettings()
    var onMove: ((CGFloat, CGFloat) -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?
    var onButton: ((TrackpadButton, Bool, Int) -> Void)?

    private var gestureTouchCount = 0
    private var gestureStartedAt: TimeInterval = 0
    private var lastCentroid: CGPoint?
    private var totalMovement: CGFloat = 0
    private var dragging = false

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
            onScroll?(delta.x, delta.y)
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouches(in: event).isEmpty else { return }
        let duration = (touches.map(\.timestamp).max() ?? gestureStartedAt) - gestureStartedAt
        if dragging {
            endDrag()
        } else if totalMovement < 10, duration < 0.35 {
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
}
