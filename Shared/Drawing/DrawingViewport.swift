import CoreGraphics

/// Local magnification of the Draw surface, so a finger can write larger on
/// screen than the stroke it produces.
///
/// This is presentation only. Strokes stay in normalized, top-left-origin
/// coordinates, and nothing about the viewport is transmitted: zooming in to
/// write more finely must land on the Mac exactly where the unzoomed stroke
/// would have. Both the video layer and the annotation layer apply the same
/// transform, which is what keeps them aligned.
struct DrawingViewport: Sendable, Equatable {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 4
    /// Below this the user has clearly pinched back out, so the viewport snaps
    /// clean instead of leaving a fraction of a percent of drift behind.
    static let snapBackScale: CGFloat = 1.02

    private(set) var scale: CGFloat = 1
    private(set) var offset: CGPoint = .zero

    var isMagnified: Bool { scale > Self.snapBackScale }

    /// `factor` is a relative pinch ratio, so successive gesture updates compose.
    mutating func magnify(by factor: CGFloat, in viewport: CGSize) {
        guard factor.isFinite, factor > 0 else { return }
        let proposed = (scale * factor).clamped(to: Self.minimumScale...Self.maximumScale)
        guard proposed > Self.snapBackScale else { return reset() }
        // Keep the visible centre stable as the scale changes.
        let ratio = proposed / scale
        scale = proposed
        offset = clampedOffset(CGPoint(x: offset.x * ratio, y: offset.y * ratio), in: viewport)
    }

    mutating func pan(by translation: CGPoint, in viewport: CGSize) {
        guard isMagnified, translation.x.isFinite, translation.y.isFinite else { return }
        offset = clampedOffset(
            CGPoint(x: offset.x + translation.x, y: offset.y + translation.y),
            in: viewport
        )
    }

    mutating func reset() {
        scale = 1
        offset = .zero
    }

    /// A centre-anchored scale exposes `(scale - 1) / 2` of the content beyond
    /// each edge. Panning further than that would drag empty space into view.
    private func clampedOffset(_ point: CGPoint, in viewport: CGSize) -> CGPoint {
        let limitX = max(0, viewport.width * (scale - 1) / 2)
        let limitY = max(0, viewport.height * (scale - 1) / 2)
        return CGPoint(
            x: point.x.clamped(to: -limitX...limitX),
            y: point.y.clamped(to: -limitY...limitY)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
