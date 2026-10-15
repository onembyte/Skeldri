import Foundation

/// The iPad's wait for the Mac owner to allow or reject a connection.
///
/// The Mac rejects an unanswered request after `macDecisionTimeout`. If that
/// rejection never arrives (the connection stalled before the Mac saw it, or
/// the Mac vanished), the iPad gives up itself after the longer `timeout`.
/// Every attempt has its own number, so a timer left over from an earlier
/// attempt can never cancel a newer one.
struct ApprovalWait: Equatable, Sendable {
    static let macDecisionTimeout: TimeInterval = 60
    static let timeout: TimeInterval = 75

    private(set) var attempt: UInt64 = 0
    private(set) var isWaiting = false

    /// Starts waiting and returns the attempt a timeout must name.
    mutating func begin() -> UInt64 {
        attempt &+= 1
        isWaiting = true
        return attempt
    }

    /// The Mac decided, the person cancelled, or the connection ended.
    mutating func end() { isWaiting = false }

    /// A timer for `attempt` fired. Returns true, once, when that attempt is
    /// still waiting and the iPad should give up.
    mutating func timeoutFired(for attempt: UInt64) -> Bool {
        guard isWaiting, attempt == self.attempt else { return false }
        isWaiting = false
        return true
    }
}
