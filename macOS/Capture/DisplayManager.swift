import AppKit
import ScreenCaptureKit

/// Converts ScreenCaptureKit's current shareable displays into stable UI descriptors.
struct DisplayManager {
    func availableDisplays() async throws -> [(SCDisplay, DisplayDescriptor)] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays.map { display in
            let screenName = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID })?.localizedName
            return (display, DisplayDescriptor(id: display.displayID, name: screenName ?? "Display \(display.displayID)", width: display.width, height: display.height))
        }
    }
}

