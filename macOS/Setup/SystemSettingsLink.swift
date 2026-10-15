import AppKit

/// Opens the System Settings pane where a permission is switched on. Skeldri
/// only shows the pane; it never changes a privacy setting itself.
enum SystemSettingsLink {
    case screenRecording
    case accessibility

    private var url: URL? {
        switch self {
        case .screenRecording:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

    @MainActor func open() {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
