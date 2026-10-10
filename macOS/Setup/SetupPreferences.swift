import Foundation

/// Remembers the Mac's setup progress in the app's own defaults: whether the
/// guide was completed, and whether each one-shot macOS prompt was already used.
/// (UserDefaults is declared in the privacy manifest under reason CA92.1.)
@MainActor
final class SetupPreferences {
    private let defaults: UserDefaults

    private enum Key {
        static let completedGuideRevision = "setup.completedGuideRevision"
        static let requestedScreenRecording = "setup.requestedScreenRecording"
        static let requestedPointerControl = "setup.requestedPointerControl"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var completedGuideRevision: Int? {
        get { defaults.object(forKey: Key.completedGuideRevision) as? Int }
        set { defaults.set(newValue, forKey: Key.completedGuideRevision) }
    }

    var hasRequestedScreenRecording: Bool {
        get { defaults.bool(forKey: Key.requestedScreenRecording) }
        set { defaults.set(newValue, forKey: Key.requestedScreenRecording) }
    }

    var hasRequestedPointerControl: Bool {
        get { defaults.bool(forKey: Key.requestedPointerControl) }
        set { defaults.set(newValue, forKey: Key.requestedPointerControl) }
    }
}
