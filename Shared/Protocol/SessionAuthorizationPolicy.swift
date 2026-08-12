import Foundation

/// Pure trust-boundary rules shared by both server adapters. Keeping these
/// invariants independent of Network.framework makes channel hijack regressions
/// deterministic to test.
enum SessionAuthorizationPolicy {
    static func acceptsVideo(sessionID: UUID, controlSessionID: UUID?) -> Bool {
        controlSessionID == nil || controlSessionID == sessionID
    }

    static func mayTransmit(authorized: Bool, controlSessionID: UUID?, videoSessionID: UUID?) -> Bool {
        authorized && controlSessionID != nil && controlSessionID == videoSessionID
    }
}
