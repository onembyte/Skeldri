import CoreGraphics
import Foundation

/// Geometry-only whole-stroke eraser used identically by presentation layers.
enum StrokeHitTesting {
    static func hitStrokeIDs(at point: CGPoint, strokes: [Stroke], canvasSize: CGSize,
                             additionalTolerance: CGFloat = 10) -> [UUID] {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return [] }
        return strokes.compactMap { stroke in
            let width = CGFloat(stroke.style.normalizedWidth) * min(canvasSize.width, canvasSize.height)
            let threshold = max(width / 2 + additionalTolerance, 1)
            let rendered = stroke.points.map { CGPoint(x: CGFloat($0.x) * canvasSize.width, y: CGFloat($0.y) * canvasSize.height) }
            guard !rendered.isEmpty else { return nil }
            if rendered.count == 1 { return distance(point, rendered[0]) <= threshold ? stroke.id : nil }
            for index in 1..<rendered.count where distanceToSegment(point, rendered[index - 1], rendered[index]) <= threshold {
                return stroke.id
            }
            return nil
        }
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private static func distanceToSegment(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x, dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(point, start) }
        let t = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return distance(point, CGPoint(x: start.x + t * dx, y: start.y + t * dy))
    }
}
