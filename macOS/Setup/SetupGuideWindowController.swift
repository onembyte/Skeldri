import AppKit
import SwiftUI

/// Shows the setup guide in an ordinary titled window. A menu-bar-only app has
/// no Dock icon or main window, so it must activate itself to bring this front.
@MainActor
final class SetupGuideWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private let model: MacAppModel

    init(model: MacAppModel) {
        self.model = model
    }

    func show() {
        let window = window ?? makeWindow()
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let root = SetupGuideScreen(model: model) { [weak self] in self?.window?.close() }
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.title = "Skeldri Setup"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        // Closing the guide by any means (Done, the close button, ⌘W) counts as
        // having seen it, so it does not reopen by itself at every launch.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.completeSetupGuide() }
        }
        self.window = window
        return window
    }
}

/// Binds the guide to the live app model and re-reads permissions whenever the
/// person comes back from System Settings.
private struct SetupGuideScreen: View {
    @ObservedObject var model: MacAppModel
    let onDone: () -> Void

    var body: some View {
        SetupGuideView(
            state: model.setupGuideState,
            onScreenRecording: model.requestCapturePermission,
            onPointerControl: model.requestInputPermission,
            onDone: onDone
        )
        .onAppear { model.refreshPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermissions()
        }
    }
}
