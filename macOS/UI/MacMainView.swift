import SwiftUI

struct MacMainView: View {
    @ObservedObject var model: MacAppModel
    var body: some View {
        Form {
            Text("DrawPad").font(.largeTitle).bold()
            ConnectionStatusView(title: "Screen Recording", ready: model.capturePermission, detail: model.capturePermission ? "Ready" : "Permission required")
            ConnectionStatusView(title: "Local Network", ready: model.listenerReady, detail: model.listenerReady ? "Ready" : "Starting")
            LabeledContent("Display", value: model.displays.first(where: { $0.id == model.selectedDisplayID })?.name ?? "Unavailable")
            ConnectionStatusView(title: "iPad", ready: model.connected, detail: model.connected ? "Connected" : "Waiting")
            HStack { Button(model.annotationsVisible ? "Hide annotations" : "Show annotations") { model.toggleOverlay() }; Button("Clear") { model.clear() } }
            if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
        }.padding(24).frame(width: 460)
    }
}
