import UIKit

enum DrawingInteractionMode { case draw, erase }

/// Finger-first UIKit input surface. It renders shared vector state and emits normalized use-case events.
///
/// A single finger draws. Two fingers magnify and pan the surface locally, which
/// lets the user write larger on screen than the stroke they produce. The
/// magnification is a layer transform, so `touch.location(in: self)` stays in
/// this view's own coordinate space and normalized stroke coordinates are
/// unaffected by zoom.
final class TouchDrawingUIView: UIView {
    var strokes: [Stroke] = [] { didSet { setNeedsDisplay() } }
    var style: StrokeStyle = .defaultPen
    var mode: DrawingInteractionMode = .draw
    var videoAspectRatio: CGFloat = 16 / 10
    var onPacket: ((ControlPacket) -> Void)?
    var onViewportChanged: ((DrawingViewport) -> Void)?
    /// Owned here while gestures run; assigning from outside only re-syncs state.
    var viewport = DrawingViewport()
    private var activeID: UUID?
    private var activeTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Multi-touch must reach the gesture recognizers; the drawing path below
        // deliberately follows one tracked touch and ignores the rest.
        isMultipleTouchEnabled = true
        isOpaque = false
        clearsContextBeforeDrawing = true
        backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        addGestureRecognizer(pan)

        let resetZoom = UITapGestureRecognizer(target: self, action: #selector(handleResetZoom(_:)))
        resetZoom.numberOfTapsRequired = 2
        resetZoom.numberOfTouchesRequired = 2
        resetZoom.delegate = self
        addGestureRecognizer(resetZoom)
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let videoRect = CoordinateMapper(container: bounds, videoAspectRatio: videoAspectRatio).videoRect
        for stroke in strokes where !stroke.points.isEmpty {
            context.setLineCap(.round); context.setLineJoin(.round)
            context.setStrokeColor(UIColor(red: CGFloat(stroke.style.red), green: CGFloat(stroke.style.green), blue: CGFloat(stroke.style.blue), alpha: CGFloat(stroke.style.alpha)).cgColor)
            context.setLineWidth(max(1, CGFloat(stroke.style.normalizedWidth) * min(videoRect.width, videoRect.height)))
            let first = stroke.points[0]; context.move(to: CGPoint(x: videoRect.minX + CGFloat(first.x) * videoRect.width, y: videoRect.minY + CGFloat(first.y) * videoRect.height))
            for point in stroke.points.dropFirst() { context.addLine(to: CGPoint(x: videoRect.minX + CGFloat(point.x) * videoRect.width, y: videoRect.minY + CGFloat(point.y) * videoRect.height)) }
            context.strokePath()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // A second finger means the user is reaching for zoom, not drawing, so
        // the mark started by the first finger is withdrawn rather than left
        // behind as an accidental scratch.
        guard liveTouchCount(in: event) == 1, let touch = touches.first else {
            discardActiveStroke()
            return
        }
        if mode == .erase { erase(at: touch.location(in: self)); return }
        guard let point = sample(touch) else { return }
        let id = UUID(); activeID = id; activeTouch = touch
        onPacket?(.strokeBegin(id: id, style: style, point: point))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if mode == .erase {
            guard let touch = touches.first, liveTouchCount(in: event) == 1 else { return }
            erase(at: touch.location(in: self))
            return
        }
        guard let id = activeID, let tracked = activeTouch, touches.contains(tracked) else { return }
        let points = (event?.coalescedTouches(for: tracked) ?? [tracked]).compactMap(sample)
        if !points.isEmpty { onPacket?(.strokePoints(id: id, points: points)) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tracked = activeTouch, touches.contains(tracked) else { return }
        finish()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Cancellation is a withdrawal, including when a gesture recognizer
        // takes the touch away to begin zooming.
        discardActiveStroke()
    }
    private func finish() {
        if let id = activeID { onPacket?(.strokeEnd(id: id)) }
        activeID = nil
        activeTouch = nil
    }
    private func discardActiveStroke() {
        guard let id = activeID else { return }
        activeID = nil
        activeTouch = nil
        onPacket?(.strokeEnd(id: id))
        onPacket?(.deleteStrokes(ids: [id]))
    }
    private func liveTouchCount(in event: UIEvent?) -> Int {
        (event?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled }.count
    }
    private func sample(_ touch: UITouch) -> StrokePoint? {
        guard let normalized = CoordinateMapper(container: bounds, videoAspectRatio: videoAspectRatio).normalizedPoint(for: touch.location(in: self)) else { return nil }
        let pressure: Float? = touch.maximumPossibleForce > 0 ? Float(touch.force / touch.maximumPossibleForce) : nil
        return StrokePoint(x: Float(normalized.x), y: Float(normalized.y), timestamp: touch.timestamp, pressure: pressure)
    }
    private func erase(at point: CGPoint) {
        let videoRect = CoordinateMapper(container: bounds, videoAspectRatio: videoAspectRatio).videoRect
        guard videoRect.contains(point) else { return }
        let localPoint = CGPoint(x: point.x - videoRect.minX, y: point.y - videoRect.minY)
        let ids = StrokeHitTesting.hitStrokeIDs(at: localPoint, strokes: strokes, canvasSize: videoRect.size)
        if !ids.isEmpty { onPacket?(.deleteStrokes(ids: ids)) }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            discardActiveStroke()
            recognizer.scale = 1
        case .changed:
            viewport.magnify(by: recognizer.scale, in: bounds.size)
            recognizer.scale = 1
            onViewportChanged?(viewport)
        default:
            break
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            discardActiveStroke()
            recognizer.setTranslation(.zero, in: self)
        case .changed:
            // Measured in the window so the delta is in the same untransformed
            // space as the offset that will be applied.
            let translation = recognizer.translation(in: window)
            viewport.pan(by: translation, in: bounds.size)
            recognizer.setTranslation(.zero, in: window)
            onViewportChanged?(viewport)
        default:
            break
        }
    }

    @objc private func handleResetZoom(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, viewport.isMagnified else { return }
        discardActiveStroke()
        viewport.reset()
        onViewportChanged?(viewport)
    }
}

extension TouchDrawingUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Pinch and two-finger pan describe one continuous zoom gesture.
        true
    }
}
