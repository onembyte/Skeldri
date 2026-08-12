import SwiftUI
import UIKit

/// Touch-driven compact rail for predictable jumps and accelerated reading
/// traversal. Its motion is integrated by elapsed display-link time rather than
/// assuming a fixed refresh rate.
final class LectureNavigationRailUIView: UIControl {
    var onPositionChanged: ((Double) -> Void)?
    var position: Double = 0 {
        didSet {
            position = position.clamped(to: 0...1)
            setNeedsDisplay()
        }
    }

    private let policy = LectureNavigationPolicy()
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var activePoint: CGPoint?
    private var directThumbDrag = false
    private var thumbTouchOffset: CGFloat = 0
    private var boundaryFeedback: Int?
    private let feedback = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = true
        accessibilityLabel = "Reading position"
        accessibilityTraits = [.adjustable]
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        displayLink?.invalidate()
    }

    override func draw(_ rect: CGRect) {
        let track = trackRect
        UIColor.white.withAlphaComponent(0.14).setFill()
        UIBezierPath(roundedRect: track, cornerRadius: track.width / 2).fill()

        let thumb = CGRect(x: bounds.midX - 8, y: thumbCenterY - 16, width: 16, height: 32)
        UIColor.tintColor.withAlphaComponent(0.88).setFill()
        UIBezierPath(roundedRect: thumb, cornerRadius: 8).fill()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        activePoint = point
        feedback.prepare()
        directThumbDrag = abs(point.y - thumbCenterY) <= 24
        if directThumbDrag {
            thumbTouchOffset = point.y - thumbCenterY
        } else {
            startDisplayLink()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        activePoint = point
        if directThumbDrag {
            setPosition(fromThumbY: point.y - thumbTouchOffset)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopInteraction()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopInteraction()
    }

    override func accessibilityIncrement() {
        publish(policy.accessibilityPosition(from: position, direction: .increment))
    }

    override func accessibilityDecrement() {
        publish(policy.accessibilityPosition(from: position, direction: .decrement))
    }

    private var trackRect: CGRect {
        CGRect(x: bounds.midX - 3, y: 18, width: 6, height: max(1, bounds.height - 36))
    }

    private var thumbCenterY: CGFloat {
        trackRect.minY + CGFloat(position) * trackRect.height
    }

    private func setPosition(fromThumbY y: CGFloat) {
        publish(Double((y - trackRect.minY) / trackRect.height))
    }

    private func publish(_ newPosition: Double) {
        let clamped = newPosition.clamped(to: 0...1)
        position = clamped
        accessibilityValue = "\(Int(clamped * 100)) percent"
        onPositionChanged?(clamped)
        emitBoundaryFeedbackIfNeeded()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        lastTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let point = activePoint else { return }
        defer { lastTimestamp = link.timestamp }
        guard let lastTimestamp else { return }
        let elapsed = min(0.1, max(0, link.timestamp - lastTimestamp))
        let displacement = Double((point.y - thumbCenterY) / max(1, bounds.height / 2))
        let horizontalDistance = Double(abs(point.x - bounds.midX))
        let velocity = policy.velocity(
            verticalDisplacement: displacement,
            horizontalDistance: horizontalDistance
        )
        publish(policy.integrate(position: position, velocity: velocity, elapsed: elapsed))
    }

    private func emitBoundaryFeedbackIfNeeded() {
        let boundary = position <= 0 ? 0 : position >= 1 ? 1 : nil
        if boundary != nil, boundary != boundaryFeedback { feedback.selectionChanged() }
        boundaryFeedback = boundary
    }

    private func stopInteraction() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
        activePoint = nil
        directThumbDrag = false
        boundaryFeedback = nil
    }
}

struct LectureNavigationRailRepresentable: UIViewRepresentable {
    @Binding var position: Double

    func makeUIView(context: Context) -> LectureNavigationRailUIView {
        let view = LectureNavigationRailUIView()
        view.onPositionChanged = { position = $0 }
        return view
    }

    func updateUIView(_ view: LectureNavigationRailUIView, context: Context) {
        view.position = position
        view.onPositionChanged = { position = $0 }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
