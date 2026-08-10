import SwiftUI

struct DrawingToolbar: View {
    @ObservedObject var model: iPadAppModel

    private var penSelected: Bool { model.mode == .draw && model.style.tool == .pen }
    private var highlighterSelected: Bool { model.mode == .draw && model.style.tool == .highlighter }
    private var eraserSelected: Bool { model.mode == .erase }

    var body: some View {
        HStack {
            toolButton("Pen", selected: penSelected) { model.choosePen() }
            toolButton("Highlighter", selected: highlighterSelected) { model.chooseHighlighter() }
            toolButton("Eraser", selected: eraserSelected) { model.mode = .erase }
            ColorPicker("Color", selection: $model.color, supportsOpacity: false).labelsHidden().onChange(of: model.color) { model.updateColor($1) }
            Slider(value: $model.width, in: 0.002...0.03).frame(width: 120).onChange(of: model.width) { model.updateWidth($1) }
            Button("Undo") { model.undo() }
            Button("Clear", role: .destructive) { model.clear() }
            Circle().fill(model.connected ? .green : .red).frame(width: 10, height: 10)
        }.padding(10).background(.ultraThinMaterial, in: Capsule())
    }

    /// Gives every mutually exclusive drawing mode the same selection treatment.
    private func toolButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(selected ? .blue : .gray)
    }
}
