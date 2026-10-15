/// What to do with the optional listener for Skeldri Afi, the separately
/// installed client for iPads too old for the App Store app.
enum LegacyListenerAction: Equatable, Sendable {
    case start
    case stop
    case none
}

/// The Afi listener advertises a second Bonjour service, so it runs only when
/// the Mac's owner allows older iPads. Every Afi connection still needs the
/// same explicit approval as a modern iPad.
enum LegacyCompatibilityPolicy {
    static let allowsOlderIPadsByDefault = false

    static func action(allowsOlderIPads: Bool, isListening: Bool) -> LegacyListenerAction {
        switch (allowsOlderIPads, isListening) {
        case (true, false): .start
        case (false, true): .stop
        default: .none
        }
    }
}
