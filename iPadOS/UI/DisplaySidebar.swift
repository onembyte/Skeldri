import SwiftUI

/// iPad-owned navigation for the Mac-authoritative display selection.
struct DisplaySidebar: View {
    @ObservedObject var model: iPadAppModel

    var body: some View {
        VStack(spacing: 7) {
            if model.displays.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 38, height: 38)
                    .accessibilityLabel("Loading displays")
            } else {
                ForEach(Array(model.displays.enumerated()), id: \.element.id) { index, display in
                    Button {
                        model.selectDisplay(display.id)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(model.selectedDisplayID == display.id ? Color.accentColor : Color.primary.opacity(0.72), lineWidth: 1.5)
                                .frame(width: 27, height: 19)
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                            if model.pendingDisplayID == display.id {
                                ProgressView()
                                    .controlSize(.mini)
                                    .offset(x: 14, y: -11)
                            }
                        }
                        .foregroundStyle(model.selectedDisplayID == display.id ? Color.accentColor : Color.primary)
                        .frame(width: 38, height: 38)
                        .background {
                            Circle().fill(model.selectedDisplayID == display.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.055))
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.pendingDisplayID == display.id)
                    .accessibilityLabel("Display \(index + 1), \(display.name)")
                    .accessibilityValue(model.selectedDisplayID == display.id ? "Selected" : "Not selected")
                }

                Capsule()
                    .fill(.white.opacity(0.14))
                    .frame(width: 22, height: 1)
                    .padding(.vertical, 2)

                GlassIconButton(
                    accessibilityLabel: "Clear drawings when switching displays",
                    selected: model.clearsDrawingsWhenSwitchingDisplays,
                    action: { model.clearsDrawingsWhenSwitchingDisplays.toggle() }
                ) {
                    ZStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .medium))
                        Image(systemName: "eraser.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .padding(3)
                            .background(.thinMaterial, in: Circle())
                            .offset(x: 9, y: 8)
                    }
                }
                .accessibilityValue(model.clearsDrawingsWhenSwitchingDisplays ? "On" : "Off")
            }
        }
        .padding(7)
        .frame(width: 52)
        .fixedSize(horizontal: false, vertical: true)
        .liquidGlassPanel(in: Capsule())
    }
}
