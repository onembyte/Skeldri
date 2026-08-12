import Foundation

/// Makes terminal callbacks idempotent even when Network.framework reports a
/// receive EOF and a state transition for the same socket.
final class OneShotGate: @unchecked Sendable {
    private let lock = NSLock()
    private var consumed = false

    func take() -> Bool {
        lock.withLock {
            guard !consumed else { return false }
            consumed = true
            return true
        }
    }
}

/// Identifies one dual-channel connection attempt. Callbacks from cancelled
/// attempts cannot tear down or report errors for a newer attempt.
struct ConnectionGenerationGate: Sendable {
    private(set) var current: UInt64 = 0

    mutating func begin() -> UInt64 {
        current &+= 1
        return current
    }

    mutating func invalidate() { current &+= 1 }

    func contains(_ generation: UInt64) -> Bool { generation == current }
}
