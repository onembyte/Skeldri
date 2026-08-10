import Foundation
import Network

/// Reusable framed TCP receive loop with one serial ownership queue.
final class PeerConnection: @unchecked Sendable {
    var onPacket: (@Sendable (FramedPacket) -> Void)?
    var onStopped: (@Sendable () -> Void)?
    private let connection: NWConnection
    private var framer: PacketFramer
    private let sendLock = NSLock()
    private var latestSendInFlight = false
    private var pendingLatestData: Data?

    init(connection: NWConnection, maximumPayload: Int) { self.connection = connection; framer = PacketFramer(maximumPayloadLength: maximumPayload) }
    func start(queue: DispatchQueue) { connection.stateUpdateHandler = { [weak self] state in if case .ready = state { self?.receive() }; if case .failed = state { self?.onStopped?() }; if case .cancelled = state { self?.onStopped?() } }; connection.start(queue: queue) }
    func send(_ data: Data) { connection.send(content: data, completion: .contentProcessed { error in if let error { DrawPadLogger.network.error("Send failed: \(error.localizedDescription)") } }) }

    /// Sends latency-sensitive state with bounded buffering. While one payload is
    /// in flight, newer payloads replace the pending one instead of building an
    /// unbounded queue of obsolete video frames.
    func sendLatest(_ data: Data) {
        let shouldStart = sendLock.withLock {
            if latestSendInFlight {
                pendingLatestData = data
                return false
            }
            latestSendInFlight = true
            return true
        }
        if shouldStart { performLatestSend(data) }
    }

    func cancel() { connection.cancel() }

    private func performLatestSend(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error { DrawPadLogger.network.error("Send failed: \(error.localizedDescription)") }
            guard let self else { return }
            let next = self.sendLock.withLock {
                let value = self.pendingLatestData
                self.pendingLatestData = nil
                if value == nil { self.latestSendInFlight = false }
                return value
            }
            if let next { self.performLatestSend(next) }
        })
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
            guard let self else { return }
            do { if let data { for packet in try framer.append(data) { onPacket?(packet) } } } catch { DrawPadLogger.network.error("Malformed packet: \(error.localizedDescription)"); cancel(); return }
            if complete || error != nil { onStopped?(); return }
            receive()
        }
    }
}
