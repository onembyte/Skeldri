import Foundation
import Network

struct DiscoveredMac: Identifiable, Hashable {
    let endpoint: NWEndpoint
    let id: String
    let name: String
}

/// iPad Bonjour browser and dual-channel client adapter.
final class iPadNetworkClient: @unchecked Sendable {
    var onServicesChanged: (@Sendable ([DiscoveredMac]) -> Void)?
    var onStateChanged: (@Sendable (Bool, String?) -> Void)?
    var onControlPacket: (@Sendable (ControlPacket) -> Void)?
    var onVideoPacket: (@Sendable (FramedPacket) -> Void)?
    private let queue = DispatchQueue(label: "Skeldri.network.client")
    private var browser: NWBrowser?
    private var browserGeneration = 0
    private var control: PeerConnection?
    private var video: PeerConnection?
    private var sessionID = UUID()

    func startBrowsing() {
        queue.async { [weak self] in self?.restartBrowser() }
    }

    func refreshBrowsing() { startBrowsing() }

    func connect(to endpoint: NWEndpoint) {
        disconnect()
        sessionID = UUID()
        control = makeConnection(endpoint: endpoint, channel: .control, maximum: PacketFramer.controlLimit,
                                 sessionID: sessionID)
        video = makeConnection(endpoint: endpoint, channel: .video, maximum: PacketFramer.videoLimit,
                               sessionID: sessionID)
    }

    func disconnect() { control?.cancel(); video?.cancel(); control = nil; video = nil; onStateChanged?(false, nil) }
    func send(_ packet: ControlPacket) { guard let data = try? JSONEncoder().encode(packet) else { return }; control?.send(PacketFramer.frame(type: .control, payload: data)) }

    private func makeConnection(endpoint: NWEndpoint, channel: ConnectionChannel, maximum: Int,
                                sessionID: UUID) -> PeerConnection {
        let peer = PeerConnection(connection: NWConnection(to: endpoint, using: .tcp), maximumPayload: maximum)
        peer.onPacket = { [weak self] packet in
            guard let self else { return }
            if channel == .control, packet.type == .control, let message = try? JSONDecoder().decode(ControlPacket.self, from: packet.payload) { onControlPacket?(message) }
            if channel == .video { onVideoPacket?(packet) }
        }
        peer.onStopped = { [weak self] in self?.onStateChanged?(false, "Connection lost") }
        peer.start(queue: queue)
        let hello = ControlPacket.hello(version: ProtocolVersion.current, channel: channel, client: "iPad",
                                        sessionID: sessionID)
        if let payload = try? JSONEncoder().encode(hello) { peer.send(PacketFramer.frame(type: .control, payload: payload)) }
        return peer
    }

    private func restartBrowser() {
        browserGeneration += 1
        let generation = browserGeneration
        browser?.browseResultsChangedHandler = nil
        browser?.stateUpdateHandler = nil
        browser?.cancel()
        browser = nil
        onServicesChanged?([])

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_skeldri._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, generation == browserGeneration else { return }
            onServicesChanged?(deduplicatedServices(from: results))
        }
        browser.stateUpdateHandler = { [weak self] state in
            guard let self, generation == browserGeneration else { return }
            if case let .failed(error) = state {
                onStateChanged?(false, "Couldn't search for Macs: \(error.localizedDescription)")
            }
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    private func deduplicatedServices(from results: Set<NWBrowser.Result>) -> [DiscoveredMac] {
        var unique: [String: DiscoveredMac] = [:]
        for result in results {
            let endpoint = result.endpoint
            let serviceName: String
            if case let .service(name, _, _, _) = endpoint { serviceName = name }
            else { serviceName = String(describing: endpoint) }

            let stableID: String?
            if case let .bonjour(record) = result.metadata { stableID = record["id"] }
            else { stableID = nil }

            let identity = DiscoveryIdentity.key(stableID: stableID, serviceName: serviceName)
            let candidate = DiscoveredMac(endpoint: endpoint, id: identity, name: serviceName)
            if let current = unique[identity] {
                // Prefer the original name over Bonjour's longer auto-renamed duplicate.
                if candidate.name.count < current.name.count { unique[identity] = candidate }
            } else {
                unique[identity] = candidate
            }
        }
        return unique.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
