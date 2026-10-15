import AppKit
import ScreenCaptureKit

/// Resolves the Mac's shareable content into Lecture reading sources, and keeps
/// the ScreenCaptureKit handles needed to start capture for whichever source
/// the Mac's owner approves.
///
/// The peer only ever sees `LectureSourceDescriptor` values. It never receives a
/// `SCWindow`, and it cannot name a source that this enumerator did not offer.
@MainActor
struct LectureSourceEnumerator {
    struct Catalog {
        let sources: [LectureSourceDescriptor]
        private let windows: [UInt32: SCWindow]
        private let displays: [UInt32: SCDisplay]

        init(sources: [LectureSourceDescriptor], windows: [UInt32: SCWindow], displays: [UInt32: SCDisplay]) {
            self.sources = sources
            self.windows = windows
            self.displays = displays
        }

        /// Window and display identifiers are both `UInt32` and share no
        /// namespace, so the kind selects the table before the id is used.
        func captureSource(
            for descriptor: LectureSourceDescriptor,
            excludingApplications: [SCRunningApplication]
        ) -> CaptureSource? {
            switch descriptor.kind {
            case .window:
                guard let window = windows[descriptor.id] else { return nil }
                return .window(window)
            case .display:
                guard let display = displays[descriptor.id] else { return nil }
                return .display(display, excludingApplications: excludingApplications)
            }
        }

        func contains(_ descriptor: LectureSourceDescriptor) -> Bool {
            switch descriptor.kind {
            case .window: windows[descriptor.id] != nil
            case .display: displays[descriptor.id] != nil
            }
        }
    }

    func catalog(ownBundleIdentifier: String?) async throws -> Catalog {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let candidates = content.windows.map { window in
            LectureWindowCandidate(
                id: window.windowID,
                title: window.title,
                applicationName: window.owningApplication?.applicationName,
                bundleIdentifier: window.owningApplication?.bundleIdentifier,
                width: Int(window.frame.width.rounded()),
                height: Int(window.frame.height.rounded()),
                isOnScreen: window.isOnScreen,
                layer: window.windowLayer
            )
        }
        let windowSources = LectureSourceCatalog.windowSources(
            from: candidates, excludingBundleIdentifier: ownBundleIdentifier
        )
        let offeredWindowIDs = Set(windowSources.map(\.id))

        let displaySources = content.displays.map {
            LectureSourceCatalog.displaySource(from: descriptor(for: $0))
        }

        return Catalog(
            sources: displaySources + windowSources,
            // Retain handles only for windows that survived the eligibility
            // rules, so an excluded window can never be started later.
            windows: Dictionary(
                content.windows
                    .filter { offeredWindowIDs.contains($0.windowID) }
                    .map { ($0.windowID, $0) },
                uniquingKeysWith: { first, _ in first }
            ),
            displays: Dictionary(
                content.displays.map { ($0.displayID, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        )
    }

    private func descriptor(for display: SCDisplay) -> DisplayDescriptor {
        let screenName = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }?.localizedName
        return DisplayDescriptor(
            id: display.displayID,
            name: screenName ?? "Display \(display.displayID)",
            width: display.width,
            height: display.height
        )
    }
}
