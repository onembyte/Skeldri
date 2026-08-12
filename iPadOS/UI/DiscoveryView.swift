import SwiftUI

struct DiscoveryView: View {
    @ObservedObject var model: iPadAppModel
    var body: some View {
        NavigationStack {
            List(model.macs) { mac in
                HStack {
                    VStack(alignment: .leading) {
                        Text(mac.name)
                        Text("Available").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Connect") { model.connect(mac) }
                }
            }
            .refreshable { model.refreshDiscovery() }
            .overlay {
                if model.macs.isEmpty {
                    Text("NEW AVAILABLE CONNECTIONS WILL APPEAR HERE")
                        .font(.system(.callout, design: .monospaced, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Skeldri")
        }
    }
}
