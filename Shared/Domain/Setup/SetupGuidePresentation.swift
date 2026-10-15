/// Decides when the Mac's setup guide opens by itself. Skeldri lives only in the
/// menu bar, so without the guide a first launch shows nothing at all.
enum SetupGuidePresentation {
    /// Increase when the guide gains a step that existing users must see.
    static let currentRevision = 1

    static func presentsAtLaunch(completedRevision: Int?) -> Bool {
        (completedRevision ?? 0) < currentRevision
    }
}
