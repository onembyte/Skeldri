import AppKit
import SwiftUI

struct MacMainView: View {
    @ObservedObject var model: MacAppModel
    @State private var showingPrivacy = false
    private static let sourceRowHeight: CGFloat = 24
    private static let maximumVisibleSourceRows = 6

    private static func listHeight(rows: Int) -> CGFloat {
        let visible = min(max(rows, 1), maximumVisibleSourceRows)
        return CGFloat(visible) * (sourceRowHeight + 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Skeldri").font(.title2).bold()
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .help("Quit Skeldri")
            }
            ConnectionStatusView(title: "Screen Recording", ready: model.capturePermission, detail: model.capturePermission ? "Ready" : "Permission required")
            if !model.capturePermission {
                Button("Grant Screen Recording") { model.requestCapturePermission() }
            }
            ConnectionStatusView(title: "Local Network", ready: model.listenerReady, detail: model.listenerReady ? "Ready" : "Starting")
            ConnectionStatusView(title: "Trackpad Control", ready: model.inputPermission, detail: model.inputPermission ? "Ready" : "Optional")
            if !model.inputPermission {
                Button("Enable Trackpad Control") { model.requestInputPermission() }
            }
            LabeledContent("Display", value: model.displays.first(where: { $0.id == model.selectedDisplayID })?.name ?? "Unavailable")
            if let pending = model.pendingConnectionName {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection request").font(.headline)
                    Text("Allow \(pending) to view this Mac and send annotations or pointer input?")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Reject", role: .cancel) { model.rejectPendingConnection() }
                        Button("Allow") { model.approvePendingConnection() }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            if let request = model.pendingLectureRequest {
                lectureSourcePicker(request)
            }
            ConnectionStatusView(title: "iPad", ready: model.connected, detail: model.connected ? "Connected" : "Waiting")
            ConnectionStatusView(title: "Screen Sharing", ready: model.streamingActive,
                                 detail: model.streamingActive ? "Active" : "Inactive")
            HStack {
                Button(model.annotationsVisible ? "Hide annotations" : "Show annotations") { model.toggleOverlay() }
                Button("Clear") { model.clear() }
            }
            Button("Privacy") { showingPrivacy = true }
                .buttonStyle(.link)
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 340)
        .onAppear { model.refreshPermissions() }
        .sheet(isPresented: $showingPrivacy) { PrivacyNoticeView() }
    }

    /// The iPad asks to read; this Mac's owner decides what it may see. Nothing
    /// is shared until a row here is chosen.
    private func lectureSourcePicker(_ request: PendingLectureRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reading request").font(.headline)
                Spacer()
                Text("\(request.sources.count) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Choose the window or display the iPad may read. It cannot draw or control this Mac while reading.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Keyed on the qualified identity: a window and a display can
                    // share the same numeric id, and duplicate ForEach ids make
                    // SwiftUI drop rows.
                    ForEach(request.sources, id: \.qualifiedIdentity) { source in
                        Button {
                            model.approveLectureSource(source)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: source.kind == .display ? "display" : "macwindow")
                                    .foregroundStyle(.secondary)
                                Text(source.name).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 0)
                            }
                            .frame(height: Self.sourceRowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(source.kind == .display ? "Display" : "Window"): \(source.name)"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // A ScrollView reports a tiny ideal height, so inside this
            // self-sizing menu-bar window it collapses and hides every row.
            // Give it a definite height derived from the row count instead.
            .frame(height: Self.listHeight(rows: request.sources.count))
            Button("Don't share", role: .cancel) { model.declineLectureSourceSelection() }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
