import AppKit

/// Owns the non-activating, click-through overlay and follows one selected screen.
@MainActor
final class OverlayWindowController {
    private(set) var window: NSPanel?
    let annotationView = MacAnnotationView()

    func show(on screen: NSScreen) {
        let panel = window ?? makePanel()
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() { window?.orderOut(nil) }
    func remove() { window?.close(); window = nil }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = annotationView
        window = panel
        return panel
    }
}

