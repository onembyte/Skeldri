import SwiftUI

struct DrawingToolbar: View {
    @ObservedObject var model: iPadAppModel

    private var penSelected: Bool { model.mode == .draw && model.style.tool == .pen }
    private var highlighterSelected: Bool { model.mode == .draw && model.style.tool == .highlighter }
    private var eraserSelected: Bool { model.mode == .erase }

    var body: some View {
        HStack(spacing: 6) {
            toolButton("Pen", symbol: "pencil.tip", selected: penSelected) { model.choosePen() }
            toolButton("Highlighter", symbol: "highlighter", selected: highlighterSelected) { model.chooseHighlighter() }
            toolButton("Eraser", symbol: "eraser", selected: eraserSelected) { model.mode = .erase }

            divider

            ColorPicker("Color", selection: $model.color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 38, height: 38)
                .onChange(of: model.color) { model.updateColor($1) }

            Image(systemName: "lineweight")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: $model.width, in: 0.002...0.03)
                .frame(width: 92)
                .controlSize(.small)
                .onChange(of: model.width) { model.updateWidth($1) }
                .accessibilityLabel("Stroke thickness")

            divider

            GlassIconButton(accessibilityLabel: "Undo", action: model.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            GlassIconButton(accessibilityLabel: "Clear", destructive: true, action: model.clear) {
                Image(systemName: "trash")
            }

            Circle()
                .fill(model.connected ? .green : .red)
                .frame(width: 8, height: 8)
                .overlay { Circle().stroke(.white.opacity(0.7), lineWidth: 1) }
                .padding(.horizontal, 5)
                .accessibilityLabel(model.connected ? "Connected" : "Disconnected")
        }
        .padding(7)
        .liquidGlassPanel(in: Capsule())
    }

    /// Gives every mutually exclusive drawing mode the same selection treatment.
    private func toolButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        GlassIconButton(accessibilityLabel: title, selected: selected, action: action) {
            Image(systemName: symbol)
        }
    }

    private var divider: some View {
        Capsule()
            .fill(.white.opacity(0.14))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 2)
    }
}
