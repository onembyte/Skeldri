import Foundation
import Network

struct DiscoveredMac: Identifiable, Hashable { let endpoint: NWEndpoint; var id: String { String(describing: endpoint) }; var name: String { if case let .service(name, _, _, _) = endpoint { return name }; return id } }

/// iPad Bonjour browser and dual-channel client adapter.
final class iPadNetworkClient: @unchecked Sendable {
    var onServicesChanged: (@Sendable ([DiscoveredMac]) -> Void)?
    var onStateChanged: (@Sendable (Bool, String?) -> Void)?
    var onControlPacket: (@Sendable (ControlPacket) -> Void)?
    var onVideoPacket: (@Sendable (FramedPacket) -> Void)?
    private let queue = DispatchQueue(label: "DrawPad.network.client")
    private var browser: NWBrowser?
    private var control: PeerConnection?
    private var video: PeerConnection?

    func startBrowsing() {
        let browser = NWBrowser(for: .bonjour(type: "_drawpad._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in self?.onServicesChanged?(results.map { DiscoveredMac(endpoint: $0.endpoint) }.sorted { $0.name < $1.name }) }
        browser.stateUpdateHandler = { [weak self] state in if case let .failed(error) = state { self?.onStateChanged?(false, "Couldn't search for Macs: \(error.localizedDescription)") } }
        self.browser = browser; browser.start(queue: queue)
    }

    func connect(to endpoint: NWEndpoint) {
        disconnect()
        control = makeConnection(endpoint: endpoint, channel: .control, maximum: PacketFramer.controlLimit)
        video = makeConnection(endpoint: endpoint, channel: .video, maximum: PacketFramer.videoLimit)
    }

    func disconnect() { control?.cancel(); video?.cancel(); control = nil; video = nil; onStateChanged?(false, nil) }
    func send(_ packet: ControlPacket) { guard let data = try? JSONEncoder().encode(packet) else { return }; control?.send(PacketFramer.frame(type: .control, payload: data)) }

    private func makeConnection(endpoint: NWEndpoint, channel: ConnectionChannel, maximum: Int) -> PeerConnection {
        let peer = PeerConnection(connection: NWConnection(to: endpoint, using: .tcp), maximumPayload: maximum)
        peer.onPacket = { [weak self] packet in
            guard let self else { return }
            if channel == .control, packet.type == .control, let message = try? JSONDecoder().decode(ControlPacket.self, from: packet.payload) { onControlPacket?(message) }
            if channel == .video { onVideoPacket?(packet) }
        }
        peer.onStopped = { [weak self] in self?.onStateChanged?(false, "Connection lost") }
        peer.start(queue: queue)
        let hello = ControlPacket.hello(version: ProtocolVersion.current, channel: channel, client: "iPad")
        if let payload = try? JSONEncoder().encode(hello) { peer.send(PacketFramer.frame(type: .control, payload: payload)) }
        if channel == .control { onStateChanged?(true, nil) }
        return peer
    }
}

