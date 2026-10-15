import SwiftUI

/// In-app disclosure required for a feature that transmits screen and pointer
/// data. It intentionally mirrors the App Store privacy answers so the product,
/// metadata, and runtime behavior cannot drift unnoticed.
struct PrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Data collection") {
                    Text("Skeldri does not collect analytics, diagnostics, advertising data, account data, or personal information. It has no cloud service or third-party SDK.")
                }
                Section("Local connection") {
                    Text("After you approve a connection on the Mac, screen video, annotations, and optional pointer commands travel directly between your Mac and iPad on the same local network. Skeldri does not store or forward the screen stream.")
                }
                Section("On-device storage") {
                    Text("The apps store only local preferences, such as trackpad sensitivity and a non-secret Bonjour identity. Removing the app removes its stored preferences.")
                }
                Section("Permissions") {
                    Text("Screen Recording is used only to mirror the selected display. Local Network is used only to discover and connect Skeldri devices. Pointer Control is optional and is active only while Trackpad mode is selected.")
                }
            }
            .navigationTitle("Privacy")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }
}
