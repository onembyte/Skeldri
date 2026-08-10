import SwiftUI

struct DrawingCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var model: iPadAppModel
    func makeUIView(context: Context) -> TouchDrawingUIView { let view = TouchDrawingUIView(); view.onPacket = { model.handleLocal($0) }; return view }
    func updateUIView(_ view: TouchDrawingUIView, context: Context) { view.strokes = model.drawingState.strokes; view.style = model.style; view.mode = model.mode; view.videoAspectRatio = model.videoAspectRatio }
}

struct DrawingScreen: View {
    @ObservedObject var model: iPadAppModel
    var body: some View {
        ZStack(alignment: .bottom) { Color.black.ignoresSafeArea(); VideoDisplayView(decoder: model.decoder).ignoresSafeArea(); DrawingCanvasRepresentable(model: model).ignoresSafeArea(); DrawingToolbar(model: model).padding(.bottom) }
            .alert("Clear all annotations?", isPresented: $model.confirmingClear) { Button("Cancel", role: .cancel) {}; Button("Clear", role: .destructive) { model.clear() } }
    }
}
