/// Describes ownership changes between mutually exclusive iPad touch surfaces.
/// Keeping this decision in the domain layer prevents presentation code from
/// forgetting to release a pressed Mac mouse button.
struct ExperienceModeTransition: Equatable, Sendable {
    let from: SkeldriInputMode
    let to: SkeldriInputMode

    var mustResetTrackpad: Bool {
        from == .trackpad && to != .trackpad
    }
}
