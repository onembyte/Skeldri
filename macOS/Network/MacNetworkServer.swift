import Foundation
import Network

/// Bonjour TCP server that classifies each connection using its first hello packet.
final class MacNetworkServer: @unchecked Sendable {
    var onConnectionChanged: (@Sendable (Bool) -> Void)?
    var onControlPacket: (@Sendable (ControlPacket) -> Void)?
    private let queue = DispatchQueue(label: "DrawPad.network.server")
    private var listener: NWListener?
    private var control: PeerConnection?
    private var video: PeerConnection?

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.service = NWListener.Service(name: Host.current().localizedName ?? "Mac", type: "_drawpad._tcp")
        listener.stateUpdateHandler = { state in
            if case let .failed(error) = state { DrawPadLogger.network.error("Listener failed: \(error.localizedDescription)") }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() { queue.async { [weak self] in self?.control?.cancel(); self?.video?.cancel(); self?.listener?.cancel() } }

    func sendControl(_ packet: ControlPacket) {
        guard let data = try? JSONEncoder().encode(packet) else { return }
        control?.send(PacketFramer.frame(type: .control, payload: data))
    }

    private func accept(_ connection: NWConnection) {
        let peer = PeerConnection(connection: connection, maximumPayload: PacketFramer.controlLimit)
        peer.onPacket = { [weak self, weak peer] packet in self?.classifyOrHandle(peer: peer, packet: packet) }
        peer.onStopped = { [weak self, weak peer] in
            guard let self, let peer else { return }
            if self.control === peer { self.control = nil; self.onConnectionChanged?(false) }
            if self.video === peer { self.video = nil }
        }
        peer.start(queue: queue)
    }

    private func classifyOrHandle(peer: PeerConnection?, packet: FramedPacket) {
        guard let peer, packet.type == .control, let message = try? JSONDecoder().decode(ControlPacket.self, from: packet.payload) else { peer?.cancel(); return }
        if case let .hello(version, channel, _) = message {
            guard version == ProtocolVersion.current else { send(.incompatibleVersion(expected: ProtocolVersion.current), to: peer); peer.cancel(); return }
            switch channel {
            case .control: control?.cancel(); control = peer; onConnectionChanged?(true); onControlPacket?(message)
            case .video: video?.cancel(); video = peer
            }
        } else if peer === control { onControlPacket?(message) }
    }

    private func send(_ packet: ControlPacket, to peer: PeerConnection) {
        if let data = try? JSONEncoder().encode(packet) { peer.send(PacketFramer.frame(type: .control, payload: data)) }
    }
}
