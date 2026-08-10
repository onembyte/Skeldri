import UIKit

enum DrawingInteractionMode { case draw, erase }

/// Finger-first UIKit input surface. It renders shared vector state and emits normalized use-case events.
final class TouchDrawingUIView: UIView {
    var strokes: [Stroke] = [] { didSet { setNeedsDisplay() } }
    var style: StrokeStyle = .defaultPen
    var mode: DrawingInteractionMode = .draw
    var videoAspectRatio: CGFloat = 16 / 10
    var onPacket: ((ControlPacket) -> Void)?
    private var activeID: UUID?

    override init(frame: CGRect) { super.init(frame: frame); isMultipleTouchEnabled = false; backgroundColor = .clear }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        for stroke in strokes where !stroke.points.isEmpty {
            context.setLineCap(.round); context.setLineJoin(.round)
            context.setStrokeColor(UIColor(red: CGFloat(stroke.style.red), green: CGFloat(stroke.style.green), blue: CGFloat(stroke.style.blue), alpha: CGFloat(stroke.style.alpha)).cgColor)
            context.setLineWidth(max(1, CGFloat(stroke.style.normalizedWidth) * min(bounds.width, bounds.height)))
            let first = stroke.points[0]; context.move(to: CGPoint(x: CGFloat(first.x) * bounds.width, y: CGFloat(first.y) * bounds.height))
            for point in stroke.points.dropFirst() { context.addLine(to: CGPoint(x: CGFloat(point.x) * bounds.width, y: CGFloat(point.y) * bounds.height)) }
            context.strokePath()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if mode == .erase { erase(at: touch.location(in: self)); return }
        guard let point = sample(touch) else { return }
        let id = UUID(); activeID = id
        onPacket?(.strokeBegin(id: id, style: style, point: point))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if mode == .erase { erase(at: touch.location(in: self)); return }
        guard let id = activeID else { return }
        let points = (event?.coalescedTouches(for: touch) ?? [touch]).compactMap(sample)
        if !points.isEmpty { onPacket?(.strokePoints(id: id, points: points)) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish() }
    private func finish() { if let id = activeID { onPacket?(.strokeEnd(id: id)) }; activeID = nil }
    private func sample(_ touch: UITouch) -> StrokePoint? {
        guard let normalized = CoordinateMapper(container: bounds, videoAspectRatio: videoAspectRatio).normalizedPoint(for: touch.location(in: self)) else { return nil }
        let pressure: Float? = touch.maximumPossibleForce > 0 ? Float(touch.force / touch.maximumPossibleForce) : nil
        return StrokePoint(x: Float(normalized.x), y: Float(normalized.y), timestamp: touch.timestamp, pressure: pressure)
    }
    private func erase(at point: CGPoint) {
        let ids = StrokeHitTesting.hitStrokeIDs(at: point, strokes: strokes, canvasSize: bounds.size)
        if !ids.isEmpty { onPacket?(.deleteStrokes(ids: ids)) }
    }
}

