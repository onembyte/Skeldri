import SwiftUI

/// iPad-owned navigation for the Mac-authoritative display selection.
struct DisplaySidebar: View {
    @ObservedObject var model: iPadAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Displays", systemImage: "rectangle.on.rectangle")
                .font(.subheadline.weight(.semibold))

            if model.displays.isEmpty {
                ProgressView("Loading…")
                    .controlSize(.small)
            } else {
                ForEach(model.displays) { display in
                    Button {
                        model.selectDisplay(display.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "display").font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(display.name).font(.caption).lineLimit(1)
                                Text("\(display.width) × \(display.height)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if model.pendingDisplayID == display.id {
                                ProgressView().controlSize(.small)
                            } else if model.selectedDisplayID == display.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 5)
                    .disabled(model.pendingDisplayID == display.id)
                }

                Divider()

                Button {
                    model.clearsDrawingsWhenSwitchingDisplays.toggle()
                } label: {
                    Label("Clear drawings when switching",
                          systemImage: model.clearsDrawingsWhenSwitchingDisplays ? "checkmark.square.fill" : "square")
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityValue(model.clearsDrawingsWhenSwitchingDisplays ? "On" : "Off")
            }
        }
        .padding(12)
        .frame(width: 170)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
    }
}
