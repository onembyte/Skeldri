import SwiftUI

struct DrawingToolbar: View {
    @ObservedObject var model: iPadAppModel

    private var penSelected: Bool { model.mode == .draw && model.style.tool == .pen }
    private var highlighterSelected: Bool { model.mode == .draw && model.style.tool == .highlighter }
    private var eraserSelected: Bool { model.mode == .erase }

    var body: some View {
        HStack(spacing: 10) {
            toolButton("Pen", symbol: "pencil.tip", selected: penSelected) { model.choosePen() }
            toolButton("Highlighter", symbol: "highlighter", selected: highlighterSelected) { model.chooseHighlighter() }
            toolButton("Eraser", symbol: "eraser", selected: eraserSelected) { model.mode = .erase }

            divider

            ForEach(0..<QuickColorPalette.slotCount, id: \.self) { index in
                quickColorSwatch(index)
            }

            ColorPicker("Color", selection: $model.color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 38, height: 38)
                .onChange(of: model.color) { model.updateColor($1) }
                .accessibilityLabel("Edit colour \(model.activeQuickColorIndex + 1)")

            Image(systemName: "lineweight")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: $model.width, in: 0.002...0.03)
                .frame(width: 118)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .liquidGlassPanel(in: Capsule())
    }

    /// A quick colour is both a one-tap choice and the target the colour picker
    /// edits, so selecting one is what makes the picker configure that slot.
    private func quickColorSwatch(_ index: Int) -> some View {
        let selected = model.activeQuickColorIndex == index
        return Button {
            model.selectQuickColor(at: index)
        } label: {
            Circle()
                .fill(iPadAppModel.swiftUIColor(model.quickColors.color(at: index)))
                .frame(width: 24, height: 24)
                .overlay {
                    Circle().stroke(.white.opacity(selected ? 0.95 : 0.35), lineWidth: selected ? 2 : 1)
                }
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Colour \(index + 1)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
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
