import Foundation
import Network

/// Bonjour TCP server that classifies each connection using its first hello packet.
final class MacNetworkServer: @unchecked Sendable {
    var onConnectionChanged: (@Sendable (Bool) -> Void)?
    var onControlPacket: (@Sendable (ControlPacket) -> Void)?
    var onVideoChannelChanged: (@Sendable (Bool) -> Void)?
    var onVideoRecoveryRequested: (@Sendable () -> Void)?
    private let queue = DispatchQueue(label: "DrawPad.network.server")
    private var listener: NWListener?
    /// Connections must be retained while waiting for their first hello packet.
    /// The channel-specific properties take ownership after classification.
    private var pendingPeers: [ObjectIdentifier: PeerConnection] = [:]
    private var control: PeerConnection?
    private var video: PeerConnection?
    private let videoFlowLock = NSLock()
    private var videoSendWindow = VideoSendWindow(maximumOutstandingFrames: 2)
    private var videoConfigurationGate = VideoConfigurationGate()
    private let serviceID: String

    init(defaults: UserDefaults = .standard) {
        let key = "DrawPadBonjourServiceID"
        if let existing = defaults.string(forKey: key) {
            serviceID = existing
        } else {
            let created = UUID().uuidString
            defaults.set(created, forKey: key)
            serviceID = created
        }
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        let record = NWTXTRecord(["id": serviceID, "protocol": String(ProtocolVersion.current)])
        listener.service = NWListener.Service(
            name: Host.current().localizedName ?? "Mac",
            type: "_drawpad._tcp",
            txtRecord: record
        )
        listener.stateUpdateHandler = { state in
            if case let .failed(error) = state { DrawPadLogger.network.error("Listener failed: \(error.localizedDescription)") }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            pendingPeers.values.forEach { $0.cancel() }
            pendingPeers.removeAll()
            control?.cancel()
            video?.cancel()
            listener?.cancel()
        }
    }

    func sendControl(_ packet: ControlPacket) {
        guard let data = try? JSONEncoder().encode(packet) else { return }
        control?.send(PacketFramer.frame(type: .control, payload: data))
    }

    func sendVideoConfiguration(_ configuration: VideoConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        let shouldSend = videoFlowLock.withLock {
            guard videoConfigurationGate.shouldSend(streamID: configuration.streamID) else { return false }
            videoSendWindow.begin(streamID: configuration.streamID)
            return true
        }
        guard shouldSend else { return }
        video?.send(PacketFramer.frame(type: .videoConfiguration, payload: data))
    }

    /// Returns false when the end-to-end acknowledgement window is full. The
    /// encoder uses that signal to force an independently decodable next frame.
    func sendVideoFrame(_ accessUnit: Data, header: VideoFrameHeader) -> Bool {
        guard let video,
              videoFlowLock.withLock({ videoSendWindow.reserve(streamID: header.streamID, sequence: header.sequence) }),
              let data = try? VideoEnvelope.encode(header: header, accessUnit: accessUnit) else { return false }
        video.send(PacketFramer.frame(type: .videoFrame, payload: data))
        return true
    }

    func acknowledgeVideoFrame(streamID: UUID, through sequence: UInt64) {
        videoFlowLock.withLock { videoSendWindow.acknowledge(streamID: streamID, through: sequence) }
    }

    private func accept(_ connection: NWConnection) {
        let peer = PeerConnection(connection: connection, maximumPayload: PacketFramer.controlLimit)
        let identifier = ObjectIdentifier(peer)
        pendingPeers[identifier] = peer
        peer.onPacket = { [weak self, weak peer] packet in self?.classifyOrHandle(peer: peer, packet: packet) }
        peer.onStopped = { [weak self, weak peer] in
            guard let self, let peer else { return }
            self.pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
            if self.control === peer { self.control = nil; self.onConnectionChanged?(false) }
            if self.video === peer {
                self.video = nil
                self.videoFlowLock.withLock {
                    self.videoSendWindow.reset()
                    self.videoConfigurationGate.reset()
                }
                self.onVideoChannelChanged?(false)
            }
        }
        peer.start(queue: queue)
    }

    private func classifyOrHandle(peer: PeerConnection?, packet: FramedPacket) {
        guard let peer, packet.type == .control, let message = try? JSONDecoder().decode(ControlPacket.self, from: packet.payload) else { peer?.cancel(); return }
        if case let .hello(version, channel, _) = message {
            guard version == ProtocolVersion.current else { send(.incompatibleVersion(expected: ProtocolVersion.current), to: peer); peer.cancel(); return }
            switch channel {
            case .control:
                control?.cancel()
                control = peer
                pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
                DrawPadLogger.network.info("Control channel connected")
                onConnectionChanged?(true)
                onControlPacket?(message)
            case .video:
                video?.cancel()
                video = peer
                videoFlowLock.withLock {
                    videoSendWindow.reset()
                    videoConfigurationGate.reset()
                }
                pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
                DrawPadLogger.network.info("Video channel connected")
                onVideoChannelChanged?(true)
            }
        } else if peer === control {
            if case let .videoAcknowledgement(streamID, sequence, requiresKeyframe) = message {
                acknowledgeVideoFrame(streamID: streamID, through: sequence)
                if requiresKeyframe { onVideoRecoveryRequested?() }
            } else {
                onControlPacket?(message)
            }
        }
    }

    private func send(_ packet: ControlPacket, to peer: PeerConnection) {
        if let data = try? JSONEncoder().encode(packet) { peer.send(PacketFramer.frame(type: .control, payload: data)) }
    }
}
