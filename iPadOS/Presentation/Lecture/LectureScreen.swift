import SwiftUI

struct LectureScreen: View {
    @ObservedObject var model: iPadAppModel
    @State private var verticalPosition = 0.0
    @State private var resetRevision = 0
    @State private var controlsExpanded = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LectureViewportRepresentable(
                decoder: model.decoder,
                aspectRatio: model.videoAspectRatio,
                verticalPosition: $verticalPosition,
                resetRevision: resetRevision
            )
            .ignoresSafeArea()

            statusOverlay

            HStack(spacing: 8) {
                GlassIconButton(
                    accessibilityLabel: controlsExpanded ? "Hide reading controls" : "Show reading controls",
                    selected: controlsExpanded,
                    action: { withAnimation(.snappy(duration: 0.24)) { controlsExpanded.toggle() } }
                ) {
                    Image(systemName: "arrow.up.and.down")
                }

                if controlsExpanded {
                    VStack(spacing: 8) {
                        GlassIconButton(accessibilityLabel: "Choose reading source", action: model.requestLectureSourceSelection) {
                            Image(systemName: "rectangle.badge.plus")
                        }
                        GlassIconButton(accessibilityLabel: "Fit reading source", action: resetViewport) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                        }
                        LectureNavigationRailRepresentable(position: $verticalPosition)
                            .frame(width: 42, height: 230)
                    }
                    .padding(7)
                    .liquidGlassPanel(in: Capsule())
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 14)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch model.lectureSession.state {
        case .inactive:
            EmptyView()
        case .selectingSource:
            statusPill("Choose a window or display on your Mac", symbol: "rectangle.on.rectangle")
        case .active:
            EmptyView()
        case let .sourceUnavailable(_, reason):
            statusPill(message(for: reason), symbol: "exclamationmark.triangle")
        case .disconnected:
            statusPill("Connection lost — showing the last frame", symbol: "wifi.slash")
        }
    }

    private func statusPill(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .liquidGlassPanel(in: Capsule())
    }

    private func message(for reason: LectureSourceUnavailableReason) -> String {
        switch reason {
        case .closed: "The selected window was closed"
        case .minimized: "The selected source is minimized or unavailable"
        case .permissionRequired: "Screen Recording permission is required"
        case .captureFailed: "The selected source could not be captured"
        case .noLongerAvailable: "The selected source is no longer available"
        case .declined: "The Mac declined the reading request"
        }
    }

    private func resetViewport() {
        verticalPosition = 0
        resetRevision &+= 1
    }
}
