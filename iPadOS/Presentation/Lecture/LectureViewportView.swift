import SwiftUI
import UIKit

/// UIScrollView-backed presentation of the live decoder surface. Gestures
/// transform the most recent frame locally at iPad refresh rate and therefore
/// remain responsive even when the network video cadence is lower.
final class LectureViewportUIView: UIView, UIScrollViewDelegate {
    var onVerticalPositionChanged: ((Double) -> Void)?

    private let scrollView = UIScrollView()
    private let videoSurface = VideoSurfaceView()
    private var sourceAspectRatio: CGFloat = 16 / 10
    private var lastLayoutSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true

        scrollView.delegate = self
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.bounces = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
        scrollView.addSubview(videoSurface)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        guard bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size
        resetToFit()
    }

    func attach(decoder: H264Decoder) {
        decoder.displayLayer = videoSurface.displayLayer
    }

    func setSourceAspectRatio(_ aspectRatio: CGFloat) {
        guard aspectRatio.isFinite, aspectRatio > 0,
              abs(sourceAspectRatio - aspectRatio) > 0.000_1 else { return }
        sourceAspectRatio = aspectRatio
        resetToFit()
    }

    func resetToFit() {
        guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }
        scrollView.setZoomScale(1, animated: false)
        let viewport = scrollView.bounds.size
        let viewportAspect = viewport.width / viewport.height
        let contentSize: CGSize
        if viewportAspect > sourceAspectRatio {
            contentSize = CGSize(width: viewport.height * sourceAspectRatio, height: viewport.height)
        } else {
            contentSize = CGSize(width: viewport.width, height: viewport.width / sourceAspectRatio)
        }
        videoSurface.transform = .identity
        videoSurface.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.contentSize = contentSize
        updateCenteringInsets()
        setVerticalPosition(0)
    }

    func setVerticalPosition(_ position: Double) {
        let maximumOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        guard maximumOffset > 0 else { return }
        let target = CGFloat(position.clamped(to: 0...1)) * maximumOffset - scrollView.adjustedContentInset.top
        guard abs(scrollView.contentOffset.y - target) > 0.5 else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: target), animated: false)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        videoSurface
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateCenteringInsets()
        publishVerticalPosition()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        publishVerticalPosition()
    }

    private func updateCenteringInsets() {
        let horizontal = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
        let vertical = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    private func publishVerticalPosition() {
        let maximumOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        guard maximumOffset > 0 else {
            onVerticalPositionChanged?(0)
            return
        }
        let visibleOffset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        onVerticalPositionChanged?(Double((visibleOffset / maximumOffset).clamped(to: 0...1)))
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.05 {
            scrollView.setZoomScale(1, animated: true)
            return
        }
        let point = recognizer.location(in: videoSurface)
        let targetScale = min(2.5, scrollView.maximumZoomScale)
        let width = videoSurface.bounds.width / targetScale
        let height = videoSurface.bounds.height / targetScale
        scrollView.zoom(to: CGRect(x: point.x - width / 2, y: point.y - height / 2,
                                   width: width, height: height), animated: true)
    }
}

struct LectureViewportRepresentable: UIViewRepresentable {
    let decoder: H264Decoder
    let aspectRatio: CGFloat
    @Binding var verticalPosition: Double
    let resetRevision: Int

    final class Coordinator {
        var appliedResetRevision: Int

        init(appliedResetRevision: Int) {
            self.appliedResetRevision = appliedResetRevision
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appliedResetRevision: resetRevision)
    }

    func makeUIView(context: Context) -> LectureViewportUIView {
        let view = LectureViewportUIView()
        view.attach(decoder: decoder)
        view.setSourceAspectRatio(aspectRatio)
        view.onVerticalPositionChanged = { position in
            if abs(verticalPosition - position) > 0.001 { verticalPosition = position }
        }
        return view
    }

    func updateUIView(_ view: LectureViewportUIView, context: Context) {
        view.attach(decoder: decoder)
        view.setSourceAspectRatio(aspectRatio)
        view.onVerticalPositionChanged = { position in
            if abs(verticalPosition - position) > 0.001 { verticalPosition = position }
        }
        if context.coordinator.appliedResetRevision != resetRevision {
            context.coordinator.appliedResetRevision = resetRevision
            view.resetToFit()
        } else {
            view.setVerticalPosition(verticalPosition)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
