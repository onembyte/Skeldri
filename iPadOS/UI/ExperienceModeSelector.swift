import SwiftUI

/// Compact, mutually exclusive Draw / Trackpad / Read navigation.
/// Each segment owns its full hit target so touches cannot pass into the active
/// canvas below it.
struct ExperienceModeSelector: View {
    @Binding var selection: SkeldriInputMode

    var body: some View {
        HStack(spacing: 4) {
            segment(.drawing, symbol: "pencil.tip", label: "Draw")
            segment(.trackpad, symbol: "hand.point.up.left", label: "Trackpad")
            segment(.lecture, symbol: "book.closed", label: "Read")
        }
        .padding(5)
        .liquidGlassPanel(in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Experience mode")
    }

    private func segment(_ mode: SkeldriInputMode, symbol: String, label: String) -> some View {
        Button {
            selection = mode
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(selection == mode ? Color.accentColor : Color.primary)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(selection == mode ? Color.accentColor.opacity(0.17) : Color.clear)
                }
                .overlay {
                    Circle()
                        .stroke(selection == mode ? Color.accentColor.opacity(0.52) : Color.clear, lineWidth: 0.75)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(selection == mode ? "Selected" : "Not selected")
        .accessibilityAddTraits(selection == mode ? .isSelected : [])
    }
}
