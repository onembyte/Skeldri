/// What a permission control should offer next.
enum PermissionPromptAction: Equatable, Sendable {
    /// The permission is granted; show its status only.
    case none
    /// Ask through the system prompt.
    case request
    /// Send the person to System Settings, where the switch lives.
    case openSettings
}

/// macOS raises its Screen Recording and pointer-control prompts only once per
/// app. After that a request returns immediately without asking, so a second
/// "Allow" button would silently do nothing; it must open System Settings.
enum PermissionPrompting {
    static func action(isGranted: Bool, hasRequestedBefore: Bool) -> PermissionPromptAction {
        if isGranted { return .none }
        return hasRequestedBefore ? .openSettings : .request
    }
}
