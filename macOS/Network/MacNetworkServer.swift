import Foundation
import Network

/// Bonjour TCP server that classifies each connection using its first hello packet.
final class MacNetworkServer: @unchecked Sendable {
    var onConnectionChanged: (@Sendable (Bool) -> Void)?
    var onControlPacket: (@Sendable (ControlPacket) -> Void)?
    var onVideoChannelChanged: (@Sendable (Bool) -> Void)?
    var onVideoRecoveryRequested: (@Sendable () -> Void)?
    var onInputModeChanged: (@Sendable (SkeldriInputMode) -> Void)?
    var onTrackpadEvent: (@Sendable (TrackpadEvent) -> Void)?
    var onAuthorizationChanged: (@Sendable (Bool) -> Void)?
    var onListenerStateChanged: (@Sendable (Bool, String?) -> Void)?
    private let queue = DispatchQueue(label: "Skeldri.network.server")
    private var listener: NWListener?
    /// Connections must be retained while waiting for their first hello packet.
    /// The channel-specific properties take ownership after classification.
    private var pendingPeers: [ObjectIdentifier: PeerConnection] = [:]
    private var control: PeerConnection?
    private var video: PeerConnection?
    private var controlSessionID: UUID?
    private var videoSessionID: UUID?
    private var authorized = false
    private var authorizationGeneration = 0
    /// The experience the peer last declared. Read mode is enforced here, not
    /// only in the iPad's presentation layer.
    private var peerInputMode: SkeldriInputMode = .drawing
    private let videoFlowLock = NSLock()
    private var videoSendWindow = VideoSendWindow(maximumOutstandingFrames: 2)
    private var videoConfigurationGate = VideoConfigurationGate()
    private let serviceID: String

    init(defaults: UserDefaults = .standard) {
        let key = "SkeldriBonjourServiceID"
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
            type: "_skeldri._tcp",
            txtRecord: record
        )
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onListenerStateChanged?(true, nil)
            case let .failed(error):
                SkeldriLogger.network.error("Listener failed: \(error.localizedDescription)")
                self?.onListenerStateChanged?(false, error.localizedDescription)
            case .cancelled:
                self?.onListenerStateChanged?(false, nil)
            default:
                break
            }
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
        guard authorized else { return }
        guard let data = try? JSONEncoder().encode(packet) else { return }
        control?.send(PacketFramer.frame(type: .control, payload: data))
    }

    /// Resolves the visible Mac-side consent prompt. Until approval, the server
    /// suppresses every control mutation and all screen data.
    func authorizeCurrentClient(_ approved: Bool) {
        queue.async { [weak self] in
            guard let self, let control, controlSessionID != nil else { return }
            authorizationGeneration += 1
            authorized = approved
            send(.authorizationResult(approved: approved), to: control)
            onAuthorizationChanged?(approved)
            if !approved { disconnectCurrentClient() }
        }
    }

    func disconnectClient() {
        queue.async { [weak self] in self?.disconnectCurrentClient() }
    }

    func sendVideoConfiguration(_ configuration: VideoConfiguration) {
        guard SessionAuthorizationPolicy.mayTransmit(
            authorized: authorized, controlSessionID: controlSessionID, videoSessionID: videoSessionID
        ) else { return }
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
        guard SessionAuthorizationPolicy.mayTransmit(
            authorized: authorized, controlSessionID: controlSessionID, videoSessionID: videoSessionID
        ), let video,
              videoFlowLock.withLock({ videoSendWindow.reserve(streamID: header.streamID, sequence: header.sequence) }),
              let data = try? VideoEnvelope.encode(header: header, accessUnit: accessUnit) else { return false }
        video.send(PacketFramer.frame(type: .videoFrame, payload: data))
        return true
    }

    func acknowledgeVideoFrame(streamID: UUID, through sequence: UInt64) {
        videoFlowLock.withLock { videoSendWindow.acknowledge(streamID: streamID, through: sequence) }
    }

    private func accept(_ connection: NWConnection) {
        guard pendingPeers.count < 8 else {
            connection.cancel()
            SkeldriLogger.network.warning("Rejected excess unclassified connection")
            return
        }
        let peer = PeerConnection(connection: connection, maximumPayload: PacketFramer.controlLimit)
        let identifier = ObjectIdentifier(peer)
        pendingPeers[identifier] = peer
        peer.onPacket = { [weak self, weak peer] packet in self?.classifyOrHandle(peer: peer, packet: packet) }
        peer.onStopped = { [weak self, weak peer] in
            guard let self, let peer else { return }
            self.pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
            if self.control === peer {
                self.control = nil
                self.authorized = false
                self.controlSessionID = nil
                self.authorizationGeneration += 1
                self.video?.cancel()
                self.peerInputMode = .drawing
                self.onInputModeChanged?(.drawing)
                self.onAuthorizationChanged?(false)
                self.onConnectionChanged?(false)
            }
            if self.video === peer {
                self.video = nil
                self.videoSessionID = nil
                self.videoFlowLock.withLock {
                    self.videoSendWindow.reset()
                    self.videoConfigurationGate.reset()
                }
                self.onVideoChannelChanged?(false)
            }
        }
        peer.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 10) { [weak self, weak peer] in
            guard let self, let peer,
                  pendingPeers[identifier] === peer else { return }
            pendingPeers.removeValue(forKey: identifier)
            peer.cancel()
        }
    }

    private func classifyOrHandle(peer: PeerConnection?, packet: FramedPacket) {
        guard let peer, packet.type == .control, let message = try? JSONDecoder().decode(ControlPacket.self, from: packet.payload) else { peer?.cancel(); return }
        if case let .hello(version, channel, _, sessionID) = message {
            guard version == ProtocolVersion.current else { send(.incompatibleVersion(expected: ProtocolVersion.current), to: peer); peer.cancel(); return }
            switch channel {
            case .control:
                control?.cancel()
                authorized = false
                peerInputMode = .drawing
                controlSessionID = sessionID
                if let videoSessionID, videoSessionID != sessionID {
                    video?.cancel()
                    video = nil
                    self.videoSessionID = nil
                }
                control = peer
                pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
                SkeldriLogger.network.info("Control channel connected")
                onConnectionChanged?(true)
                onControlPacket?(message)
                send(.authorizationRequired, to: peer)
                beginAuthorizationTimeout(for: sessionID)
            case .video:
                guard SessionAuthorizationPolicy.acceptsVideo(
                    sessionID: sessionID, controlSessionID: controlSessionID
                ) else { peer.cancel(); return }
                video?.cancel()
                video = peer
                videoSessionID = sessionID
                videoFlowLock.withLock {
                    videoSendWindow.reset()
                    videoConfigurationGate.reset()
                }
                pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
                SkeldriLogger.network.info("Video channel connected")
                onVideoChannelChanged?(true)
            }
        } else if peer === control, authorized {
            guard LectureInputPolicy.allows(message, whileIn: peerInputMode) else {
                SkeldriLogger.network.warning("Rejected a mutating packet while the peer is in Read mode")
                return
            }
            if case let .videoAcknowledgement(streamID, sequence, requiresKeyframe) = message {
                acknowledgeVideoFrame(streamID: streamID, through: sequence)
                if requiresKeyframe { onVideoRecoveryRequested?() }
            } else if case let .inputMode(mode) = message {
                peerInputMode = mode
                onInputModeChanged?(mode)
            } else if case let .trackpad(event) = message {
                onTrackpadEvent?(event)
            } else {
                onControlPacket?(message)
            }
        }
    }

    private func send(_ packet: ControlPacket, to peer: PeerConnection) {
        if let data = try? JSONEncoder().encode(packet) { peer.send(PacketFramer.frame(type: .control, payload: data)) }
    }

    private func beginAuthorizationTimeout(for sessionID: UUID) {
        authorizationGeneration += 1
        let generation = authorizationGeneration
        queue.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, generation == authorizationGeneration,
                  controlSessionID == sessionID, !authorized else { return }
            if let control { send(.authorizationResult(approved: false), to: control) }
            disconnectCurrentClient()
        }
    }

    private func disconnectCurrentClient() {
        let hadControl = control != nil
        let hadVideo = video != nil
        let oldControl = control
        let oldVideo = video
        authorizationGeneration += 1
        authorized = false
        peerInputMode = .drawing
        controlSessionID = nil
        videoSessionID = nil
        control = nil
        video = nil
        videoFlowLock.withLock {
            videoSendWindow.reset()
            videoConfigurationGate.reset()
        }
        oldControl?.cancel()
        oldVideo?.cancel()
        onInputModeChanged?(.drawing)
        if hadControl {
            onAuthorizationChanged?(false)
            onConnectionChanged?(false)
        }
        if hadVideo { onVideoChannelChanged?(false) }
    }
}
