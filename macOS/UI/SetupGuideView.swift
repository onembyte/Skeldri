import AppKit
import SwiftUI

/// What the setup guide shows. A plain value, so the view can be rendered
/// without the app's networking and capture services.
struct SetupGuideState: Equatable {
    var screenRecording: PermissionPromptAction
    var pointerControl: PermissionPromptAction
}

/// The first window a person sees. Skeldri otherwise lives only in the menu
/// bar, so this explains where it went, what the iPad needs, and each
/// permission, before macOS asks for it.
struct SetupGuideView: View {
    let state: SetupGuideState
    var onScreenRecording: () -> Void = {}
    var onPointerControl: () -> Void = {}
    var onDone: () -> Void = {}
    @State private var showingPrivacy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            VStack(alignment: .leading, spacing: 16) {
                // The real menu-bar mark, so people know exactly what to look for.
                SetupStep(icon: Image("MenuBarMark"), title: "Skeldri lives in the menu bar") {
                    Text("Click its icon at the top of the screen to approve an iPad, see which display is shared, or hide and clear drawings.")
                }
                SetupStep(icon: Image(systemName: "ipad.landscape"), title: "Get Skeldri on your iPad") {
                    Text("Install Skeldri on your iPad from the App Store and join the same Wi\u{2011}Fi network as this Mac. An iPad sees nothing until you approve it here.")
                }
                SetupStep(icon: Image(systemName: "rectangle.dashed.badge.record"), title: "Screen Recording",
                          action: state.screenRecording, onAction: onScreenRecording) {
                    Text("Needed to show this Mac's screen on your iPad. Skeldri shares only the display or window you choose.")
                    if state.screenRecording == .openSettings {
                        Text("Turn on Skeldri in Screen & System Audio Recording. If macOS asks, quit and reopen Skeldri.")
                            .foregroundStyle(.secondary)
                    }
                }
                SetupStep(icon: Image(systemName: "cursorarrow.motionlines"), title: "Trackpad Control (optional)",
                          action: state.pointerControl, onAction: onPointerControl) {
                    Text("Lets your iPad move the pointer, click, scroll, and zoom while you use Trackpad mode. Skeldri never types text on this Mac.")
                    if state.pointerControl == .openSettings {
                        Text("Turn on Skeldri in Accessibility.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Button("Privacy") { showingPrivacy = true }
                    .buttonStyle(.link)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .sheet(isPresented: $showingPrivacy) { PrivacyNoticeView() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Skeldri").font(.title2).bold()
                Text("Draw on this Mac's screen from your iPad, or use your iPad as a trackpad.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One numbered idea in the guide, with an optional permission control.
private struct SetupStep<Detail: View>: View {
    let icon: Image
    let title: String
    var action: PermissionPromptAction? = nil
    var onAction: () -> Void = {}
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            icon
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    Spacer(minLength: 12)
                    if let action { control(for: action) }
                }
                detail()
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func control(for action: PermissionPromptAction) -> some View {
        switch action {
        case .none:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .request:
            Button("Allow…", action: onAction)
                .accessibilityLabel("Allow \(title)")
        case .openSettings:
            Button("Open System Settings", action: onAction)
        }
    }
}
