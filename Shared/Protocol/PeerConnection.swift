import Foundation
import Network

/// Reusable framed TCP receive loop with one serial ownership queue.
final class PeerConnection: @unchecked Sendable {
    var onPacket: (@Sendable (FramedPacket) -> Void)?
    var onStopped: (@Sendable () -> Void)?
    private let connection: NWConnection
    private var framer: PacketFramer
    private let stopGate = OneShotGate()

    init(connection: NWConnection, maximumPayload: Int) { self.connection = connection; framer = PacketFramer(maximumPayloadLength: maximumPayload) }
    func start(queue: DispatchQueue) { connection.stateUpdateHandler = { [weak self] state in if case .ready = state { self?.receive() }; if case .failed = state { self?.finish() }; if case .cancelled = state { self?.finish() } }; connection.start(queue: queue) }
    func send(_ data: Data) { connection.send(content: data, completion: .contentProcessed { [weak self] error in if let error { SkeldriLogger.network.error("Send failed: \(error.localizedDescription)"); self?.cancel(); self?.finish() } }) }

    func cancel() { connection.cancel() }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
            guard let self else { return }
            do { if let data { for packet in try framer.append(data) { onPacket?(packet) } } } catch { SkeldriLogger.network.error("Malformed packet: \(error.localizedDescription)"); cancel(); return }
            if complete || error != nil { finish(); return }
            receive()
        }
    }

    private func finish() {
        guard stopGate.take() else { return }
        onStopped?()
    }
}
