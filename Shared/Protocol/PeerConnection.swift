import Foundation
import Network

/// Shared transport configuration for both Skeldri peers.
///
/// A device that vanishes without closing its socket — an iPad powered off, a
/// device carried off the network — leaves a half-open connection that never
/// reports `.failed` or `.cancelled`. Nothing in Skeldri sends periodic
/// traffic on an idle session, so without keepalive the Mac holds that dead
/// session indefinitely and keeps presenting it as a live, authorized peer.
enum SkeldriTransport {
    /// Idle time before probing, then the spacing and number of probes. A dead
    /// peer is detected in roughly 25 seconds, fast enough that the owner is
    /// not left looking at a phantom connection, slow enough that a brief Wi-Fi
    /// stall does not drop a working session.
    static let keepaliveIdleSeconds = 10
    static let keepaliveIntervalSeconds = 5
    static let keepaliveProbeCount = 3

    static func tcpParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if let tcp = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = keepaliveIdleSeconds
            tcp.keepaliveInterval = keepaliveIntervalSeconds
            tcp.keepaliveCount = keepaliveProbeCount
        }
        return parameters
    }
}

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
