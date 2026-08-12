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
            ConnectionStatusView(title: "Local Network", ready: model.listenerReady, detail: model.listenerReady ? "Ready" : "Starting")
            ConnectionStatusView(title: "Pointer Control", ready: model.inputPermission, detail: model.inputPermission ? "Ready" : "Permission required")
            if !model.inputPermission {
                Button("Grant Pointer Permission") { model.requestInputPermission() }
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
        .onAppear { model.refreshInputPermission() }
        .sheet(isPresented: $showingPrivacy) { PrivacyNoticeView() }
    }
}
