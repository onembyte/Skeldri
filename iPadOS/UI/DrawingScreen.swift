import SwiftUI

struct DrawingCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var model: iPadAppModel
    @ObservedObject var drawingState: DrawingState

    func makeUIView(context: Context) -> TouchDrawingUIView { let view = TouchDrawingUIView(); view.onPacket = { model.handleLocal($0) }; return view }
    func updateUIView(_ view: TouchDrawingUIView, context: Context) { view.strokes = drawingState.strokes; view.style = model.style; view.mode = model.mode; view.videoAspectRatio = model.videoAspectRatio }
}

struct TrackpadRepresentable: UIViewRepresentable {
    @ObservedObject var model: iPadAppModel

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.onMove = { [weak model] in model?.sendTrackpadMove(deltaX: $0, deltaY: $1) }
        view.onScroll = { [weak model] in model?.sendTrackpadScroll(deltaX: $0, deltaY: $1) }
        view.onButton = { [weak model] in model?.sendTrackpadButton($0, isDown: $1, clickCount: $2) }
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {}
}

struct DrawingScreen: View {
    @ObservedObject var model: iPadAppModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoDisplayView(decoder: model.decoder).ignoresSafeArea()
            if model.inputMode == .drawing {
                DrawingCanvasRepresentable(model: model, drawingState: model.drawingState).ignoresSafeArea()
            } else {
                TrackpadRepresentable(model: model).ignoresSafeArea()
            }
            DisplaySidebar(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 14)
            if model.inputMode == .drawing {
                DrawingToolbar(model: model)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)
            }

            GlassIconButton(accessibilityLabel: "Back to Mac selection", action: model.disconnect) {
                Image(systemName: "chevron.left")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 14)
            .padding(.top, 14)

            GlassIconButton(
                accessibilityLabel: model.inputMode == .drawing ? "Switch to trackpad" : "Switch to drawing",
                selected: model.inputMode == .trackpad,
                action: model.toggleInputMode
            ) {
                Image(systemName: model.inputMode == .drawing ? "hand.point.up.left" : "pencil.tip")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 14)
            .padding(.top, 14)
        }
        .ignoresSafeArea(edges: .vertical)
    }
}
