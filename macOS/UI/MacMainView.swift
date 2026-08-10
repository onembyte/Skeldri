import SwiftUI

struct MacMainView: View {
    @ObservedObject var model: MacAppModel
    var body: some View {
        Form {
            Text("DrawPad").font(.largeTitle).bold()
            ConnectionStatusView(title: "Screen Recording", ready: model.capturePermission, detail: model.capturePermission ? "Ready" : "Permission required")
            ConnectionStatusView(title: "Local Network", ready: model.listenerReady, detail: model.listenerReady ? "Ready" : "Starting")
            Picker("Display", selection: $model.selectedDisplayID) { ForEach(model.displays) { Text($0.name).tag(Optional($0.id)) } }.onChange(of: model.selectedDisplayID) { model.selectDisplay($1) }
            ConnectionStatusView(title: "iPad", ready: model.connected, detail: model.connected ? "Connected" : "Waiting")
            HStack { Button(model.annotationsVisible ? "Hide annotations" : "Show annotations") { model.toggleOverlay() }; Button("Clear") { model.clear() } }
            if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
        }.padding(24).frame(width: 460)
    }
}

