import CoreGraphics

/// Maps points between a view's aspect-fit content rectangle and normalized video coordinates.
struct CoordinateMapper: Sendable {
    let container: CGRect
    let videoAspectRatio: CGFloat

    var videoRect: CGRect {
        guard container.width > 0, container.height > 0, videoAspectRatio > 0 else { return .zero }
        let containerAspect = container.width / container.height
        if containerAspect > videoAspectRatio {
            let width = container.height * videoAspectRatio
            return CGRect(x: container.minX + (container.width - width) / 2, y: container.minY,
                          width: width, height: container.height)
        }
        let height = container.width / videoAspectRatio
        return CGRect(x: container.minX, y: container.minY + (container.height - height) / 2,
                      width: container.width, height: height)
    }

    func normalizedPoint(for point: CGPoint) -> CGPoint? {
        let rect = videoRect
        guard rect.width > 0, rect.height > 0,
              point.x >= rect.minX, point.x <= rect.maxX,
              point.y >= rect.minY, point.y <= rect.maxY else { return nil }
        return CGPoint(x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
    }

    func renderedPoint(for normalized: CGPoint) -> CGPoint {
        CGPoint(x: videoRect.minX + normalized.x * videoRect.width,
                y: videoRect.minY + normalized.y * videoRect.height)
    }
}
