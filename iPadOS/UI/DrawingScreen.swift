import SwiftUI

struct DrawingCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var model: iPadAppModel
    @ObservedObject var drawingState: DrawingState

    func makeUIView(context: Context) -> TouchDrawingUIView { let view = TouchDrawingUIView(); view.onPacket = { model.handleLocal($0) }; return view }
    func updateUIView(_ view: TouchDrawingUIView, context: Context) { view.strokes = drawingState.strokes; view.style = model.style; view.mode = model.mode; view.videoAspectRatio = model.videoAspectRatio }
}

struct DrawingScreen: View {
    @ObservedObject var model: iPadAppModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoDisplayView(decoder: model.decoder).ignoresSafeArea()
            DrawingCanvasRepresentable(model: model, drawingState: model.drawingState).ignoresSafeArea()
            DisplaySidebar(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 16)
            DrawingToolbar(model: model)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom)
        }
        .ignoresSafeArea(edges: .vertical)
    }
}
