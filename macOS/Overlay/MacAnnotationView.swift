import AppKit

/// Core Graphics renderer for the Mac's mouse-transparent annotation overlay.
final class MacAnnotationView: NSView {
    var strokes: [Stroke] = [] { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setLineCap(.round); context.setLineJoin(.round)
        for stroke in strokes where !stroke.points.isEmpty {
            let style = stroke.style
            context.setStrokeColor(CGColor(red: CGFloat(style.red), green: CGFloat(style.green), blue: CGFloat(style.blue), alpha: CGFloat(style.alpha)))
            context.setLineWidth(max(1, CGFloat(style.normalizedWidth) * min(bounds.width, bounds.height)))
            context.beginPath()
            let first = stroke.points[0]
            context.move(to: CGPoint(x: CGFloat(first.x) * bounds.width, y: CGFloat(first.y) * bounds.height))
            for point in stroke.points.dropFirst() { context.addLine(to: CGPoint(x: CGFloat(point.x) * bounds.width, y: CGFloat(point.y) * bounds.height)) }
            if stroke.points.count == 1 { context.addLine(to: CGPoint(x: CGFloat(first.x) * bounds.width + 0.1, y: CGFloat(first.y) * bounds.height)) }
            context.strokePath()
        }
    }
}

