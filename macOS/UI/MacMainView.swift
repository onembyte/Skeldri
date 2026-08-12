import AppKit
import SwiftUI

struct MacMainView: View {
    @ObservedObject var model: MacAppModel
    @State private var showingPrivacy = false

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
            Text("Reading request").font(.headline)
            Text("Choose the window or display the iPad may read. It cannot draw or control this Mac while reading.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(request.sources) { source in
                        Button {
                            model.approveLectureSource(source)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: source.kind == .display ? "display" : "macwindow")
                                    .foregroundStyle(.secondary)
                                Text(source.name).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(source.kind == .display ? "Display" : "Window"): \(source.name)"
                        )
                    }
                }
            }
            .frame(maxHeight: 168)
            Button("Don't share", role: .cancel) { model.declineLectureSourceSelection() }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
