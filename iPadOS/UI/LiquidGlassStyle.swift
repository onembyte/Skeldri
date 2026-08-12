import SwiftUI

/// Shared visual language for Skeldri's floating controls.
///
/// The newest systems receive native Liquid Glass rendering. Older supported
/// iPadOS releases retain the same geometry with a material-based fallback.
struct LiquidGlassPanelModifier<PanelShape: Shape>: ViewModifier {
    let shape: PanelShape

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.stroke(.white.opacity(0.16), lineWidth: 0.75) }
                .shadow(color: .black.opacity(0.24), radius: 14, y: 7)
        }
    }
}

extension View {
    func liquidGlassPanel<S: Shape>(in shape: S) -> some View {
        modifier(LiquidGlassPanelModifier(shape: shape))
    }
}

/// Compact, label-free button shared by the side and bottom navigation bars.
struct GlassIconButton<Icon: View>: View {
    let accessibilityLabel: String
    var selected = false
    var destructive = false
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            icon()
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(destructive ? Color.red : selected ? Color.accentColor : Color.primary)
                .frame(width: 38, height: 38)
                .background {
                    Circle()
                        .fill(selected ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.055))
                }
                .overlay {
                    Circle()
                        .stroke(selected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.10), lineWidth: 0.75)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
