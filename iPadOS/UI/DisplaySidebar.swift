import SwiftUI

/// iPad-owned navigation for the Mac-authoritative display selection.
struct DisplaySidebar: View {
    @ObservedObject var model: iPadAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Displays", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            if model.displays.isEmpty {
                ProgressView("Loading…")
                    .controlSize(.small)
            } else {
                ForEach(model.displays) { display in
                    Button {
                        model.selectDisplay(display.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "display")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(display.name).lineLimit(1)
                                Text("\(display.width) × \(display.height)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if model.selectedDisplayID == display.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 220)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }
}
