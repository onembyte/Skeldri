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
    private var connectionGenerations = ConnectionGenerationGate()

    func startBrowsing() {
        queue.async { [weak self] in self?.restartBrowser() }
    }

    func refreshBrowsing() { startBrowsing() }

    func connect(to endpoint: NWEndpoint) {
        queue.async { [weak self] in
            guard let self else { return }
            disconnectCurrent(notify: false)
            let generation = connectionGenerations.begin()
            sessionID = UUID()
            control = makeConnection(endpoint: endpoint, channel: .control, maximum: PacketFramer.controlLimit,
                                     sessionID: sessionID, generation: generation)
            video = makeConnection(endpoint: endpoint, channel: .video, maximum: PacketFramer.videoLimit,
                                   sessionID: sessionID, generation: generation)
        }
    }

    func disconnect() { queue.async { [weak self] in self?.disconnectCurrent(notify: true) } }
    func send(_ packet: ControlPacket) {
        guard let data = try? JSONEncoder().encode(packet) else { return }
        let framed = PacketFramer.frame(type: .control, payload: data)
        queue.async { [weak self] in self?.control?.send(framed) }
    }

    private func makeConnection(endpoint: NWEndpoint, channel: ConnectionChannel, maximum: Int,
                                sessionID: UUID, generation: UInt64) -> PeerConnection {
        let peer = PeerConnection(connection: NWConnection(to: endpoint, using: .tcp), maximumPayload: maximum)
        peer.onPacket = { [weak self] packet in
            guard let self else { return }
            if channel == .control, packet.type == .control, let message = try? JSONDecoder().decode(ControlPacket.self, from: packet.payload) { onControlPacket?(message) }
            if channel == .video { onVideoPacket?(packet) }
        }
        peer.onStopped = { [weak self] in self?.handleUnexpectedStop(generation: generation) }
        peer.start(queue: queue)
        let hello = ControlPacket.hello(version: ProtocolVersion.current, channel: channel, client: "iPad",
                                        sessionID: sessionID)
        if let payload = try? JSONEncoder().encode(hello) { peer.send(PacketFramer.frame(type: .control, payload: payload)) }
        return peer
    }

    private func disconnectCurrent(notify: Bool) {
        connectionGenerations.invalidate()
        let oldControl = control
        let oldVideo = video
        control = nil
        video = nil
        oldControl?.cancel()
        oldVideo?.cancel()
        if notify { onStateChanged?(false, nil) }
    }

    private func handleUnexpectedStop(generation: UInt64) {
        guard connectionGenerations.contains(generation) else { return }
        disconnectCurrent(notify: false)
        onStateChanged?(false, "Connection lost. Make sure both devices are on the same local network, then reconnect.")
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
