import Foundation

/// Framework-free description of one shareable window, so the selection rules
/// below can be exercised without ScreenCaptureKit or a live window server.
struct LectureWindowCandidate: Sendable, Equatable {
    let id: UInt32
    let title: String?
    let applicationName: String?
    let bundleIdentifier: String?
    let width: Int
    let height: Int
    let isOnScreen: Bool
    /// Window server layer. Only layer 0 holds ordinary document windows;
    /// menu bars, the Dock, and floating overlays live above it.
    let layer: Int

    init(id: UInt32, title: String?, applicationName: String?, bundleIdentifier: String?,
         width: Int, height: Int, isOnScreen: Bool, layer: Int) {
        self.id = id
        self.title = title
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.width = width
        self.height = height
        self.isOnScreen = isOnScreen
        self.layer = layer
    }
}

/// Decides which Mac windows may be offered as Lecture reading sources.
///
/// Skeldri's own windows are always excluded: capturing the annotation overlay
/// or the menu-bar popover would feed the stream back into itself. Off-screen,
/// non-document, and degenerate windows are dropped because they cannot produce
/// a readable page.
enum LectureSourceCatalog {
    /// Below this, a window carries no legible text at reading distance.
    static let minimumWindowDimension = 120
    private static let maximumDimension = 16_384
    private static let maximumNameBytes = 256

    static func windowSources(
        from candidates: [LectureWindowCandidate],
        excludingBundleIdentifier ownBundleIdentifier: String?
    ) -> [LectureSourceDescriptor] {
        candidates
            .filter { isEligible($0, ownBundleIdentifier: ownBundleIdentifier) }
            .map {
                LectureSourceDescriptor(
                    id: $0.id,
                    kind: .window,
                    name: name(for: $0),
                    width: min($0.width, maximumDimension),
                    height: min($0.height, maximumDimension)
                )
            }
            // Stable ordering keeps the Mac picker from reshuffling under the
            // owner's cursor while windows come and go.
            .sorted { lhs, rhs in
                let order = lhs.name.localizedStandardCompare(rhs.name)
                return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
            }
    }

    static func displaySource(from descriptor: DisplayDescriptor) -> LectureSourceDescriptor {
        LectureSourceDescriptor(
            id: descriptor.id,
            kind: .display,
            name: bounded(descriptor.name, fallback: "Display \(descriptor.id)"),
            width: min(max(1, descriptor.width), maximumDimension),
            height: min(max(1, descriptor.height), maximumDimension)
        )
    }

    private static func isEligible(_ candidate: LectureWindowCandidate,
                                   ownBundleIdentifier: String?) -> Bool {
        if let ownBundleIdentifier, candidate.bundleIdentifier == ownBundleIdentifier { return false }
        guard candidate.isOnScreen, candidate.layer == 0 else { return false }
        return candidate.width >= minimumWindowDimension && candidate.height >= minimumWindowDimension
    }

    private static func name(for candidate: LectureWindowCandidate) -> String {
        let title = candidate.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let application = candidate.applicationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combined = switch (application.isEmpty, title.isEmpty) {
        case (false, false): "\(application) — \(title)"
        case (false, true): application
        case (true, false): title
        case (true, true): ""
        }
        return bounded(combined, fallback: "Window \(candidate.id)")
    }

    /// `LectureSourceDescriptor` rejects empty or oversized names on decode, so
    /// clamp here rather than emitting a descriptor the peer will discard.
    private static func bounded(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.utf8.count > maximumNameBytes else { return trimmed }
        // The ellipsis is three UTF-8 bytes, so it has to come out of the budget
        // rather than be appended to a name already sized to the limit.
        let ellipsis = "…"
        let budget = maximumNameBytes - ellipsis.utf8.count
        var truncated = trimmed
        while truncated.utf8.count > budget, !truncated.isEmpty {
            truncated.removeLast()
        }
        return truncated + ellipsis
    }
}
