import AVFoundation
import UIKit

/// Low-latency sample-buffer surface; the decoder feeds display-ready H.264 samples.
final class VideoSurfaceView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .black; displayLayer.videoGravity = .resizeAspect }
    required init?(coder: NSCoder) { super.init(coder: coder) }
}

import SwiftUI
struct VideoDisplayView: UIViewRepresentable {
    func makeUIView(context: Context) -> VideoSurfaceView { VideoSurfaceView() }
    func updateUIView(_ uiView: VideoSurfaceView, context: Context) {}
}

