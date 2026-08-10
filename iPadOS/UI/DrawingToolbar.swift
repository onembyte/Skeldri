import SwiftUI

struct DrawingToolbar: View {
    @ObservedObject var model: iPadAppModel
    var body: some View {
        HStack {
            Button("Pen") { model.choosePen() }.buttonStyle(.borderedProminent)
            Button("Highlighter") { model.chooseHighlighter() }
            Button("Eraser") { model.mode = .erase }
            ColorPicker("Color", selection: $model.color, supportsOpacity: false).labelsHidden().onChange(of: model.color) { model.updateColor($1) }
            Slider(value: $model.width, in: 0.002...0.03).frame(width: 120).onChange(of: model.width) { model.updateWidth($1) }
            Button("Undo") { model.undo() }
            Button("Clear", role: .destructive) { model.confirmingClear = true }
            Circle().fill(model.connected ? .green : .red).frame(width: 10, height: 10)
        }.padding(10).background(.ultraThinMaterial, in: Capsule())
    }
}

