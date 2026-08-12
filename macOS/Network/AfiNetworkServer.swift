import Foundation
import Network

/// Dedicated listener for 32-bit iOS 10 clients. It translates the explicit
/// Afi envelope into the same domain events used by the modern server.
final class AfiNetworkServer: @unchecked Sendable {
    var onConnectionChanged: (@Sendable (Bool) -> Void)?
    var onControlPacket: (@Sendable (ControlPacket) -> Void)?
    var onVideoChannelChanged: (@Sendable (Bool) -> Void)?
    var onVideoRecoveryRequested: (@Sendable () -> Void)?
    var onInputModeChanged: (@Sendable (SkeldriInputMode) -> Void)?
    var onTrackpadEvent: (@Sendable (TrackpadEvent) -> Void)?
    var onAuthorizationChanged: (@Sendable (Bool) -> Void)?

    private let queue = DispatchQueue(label: "Skeldri.network.afi")
    private var listener: NWListener?
    private var pendingPeers: [ObjectIdentifier: PeerConnection] = [:]
    private var control: PeerConnection?
    private var video: PeerConnection?
    private var controlSessionID: UUID?
    private var videoSessionID: UUID?
    private var authorized = false
    private var authorizationGeneration = 0
    private let videoFlowLock = NSLock()
    private var videoSendWindow = VideoSendWindow(maximumOutstandingFrames: 2)
    private var videoConfigurationGate = VideoConfigurationGate()
    private var acceptsClients = true
    private let serviceID: String

    init(defaults: UserDefaults = .standard) {
        let key = "SkeldriAfiBonjourServiceID"
        if let existing = defaults.string(forKey: key) { serviceID = existing }
        else {
            serviceID = UUID().uuidString
            defaults.set(serviceID, forKey: key)
        }
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.service = NWListener.Service(
            name: Host.current().localizedName ?? "Mac",
            type: AfiProtocol.serviceType,
            txtRecord: NWTXTRecord(["id": serviceID, "protocol": String(AfiProtocol.version)])
        )
        listener.stateUpdateHandler = { state in
            if case let .failed(error) = state {
                SkeldriLogger.network.error("Afi listener failed: \(error.localizedDescription)")
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

    func disconnectClient() {
        queue.async { [weak self] in self?.disconnectCurrentClient() }
    }

    func authorizeCurrentClient(_ approved: Bool) {
        queue.async { [weak self] in
            guard let self, control != nil, controlSessionID != nil else { return }
            authorizationGeneration += 1
            authorized = approved
            onAuthorizationChanged?(approved)
            if !approved { disconnectCurrentClient() }
        }
    }

    func setAcceptingClients(_ accepting: Bool) {
        queue.async { [weak self] in self?.acceptsClients = accepting }
    }

    func sendControl(_ packet: ControlPacket) {
        guard authorized else { return }
        guard let data = try? AfiControlCodec.encode(packet) else { return }
        control?.send(PacketFramer.frame(type: .control, payload: data))
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

    func sendVideoFrame(_ accessUnit: Data, header: VideoFrameHeader) -> Bool {
        guard SessionAuthorizationPolicy.mayTransmit(
            authorized: authorized, controlSessionID: controlSessionID, videoSessionID: videoSessionID
        ), let video,
              videoFlowLock.withLock({ videoSendWindow.reserve(streamID: header.streamID, sequence: header.sequence) }),
              let data = try? VideoEnvelope.encode(header: header, accessUnit: accessUnit) else { return false }
        video.send(PacketFramer.frame(type: .videoFrame, payload: data))
        return true
    }

    private func accept(_ connection: NWConnection) {
        guard acceptsClients else {
            connection.cancel()
            SkeldriLogger.network.info("Rejected Afi client while modern Skeldri is connected")
            return
        }
        guard pendingPeers.count < 8 else {
            connection.cancel()
            SkeldriLogger.network.warning("Rejected excess unclassified Afi connection")
            return
        }
        let peer = PeerConnection(connection: connection, maximumPayload: PacketFramer.controlLimit)
        let identifier = ObjectIdentifier(peer)
        pendingPeers[identifier] = peer
        peer.onPacket = { [weak self, weak peer] packet in self?.classifyOrHandle(peer: peer, packet: packet) }
        peer.onStopped = { [weak self, weak peer] in
            guard let self, let peer else { return }
            pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
            if control === peer {
                control = nil
                authorized = false
                controlSessionID = nil
                authorizationGeneration += 1
                video?.cancel()
                onInputModeChanged?(.drawing)
                onAuthorizationChanged?(false)
                onConnectionChanged?(false)
            }
            if video === peer {
                video = nil
                videoSessionID = nil
                videoFlowLock.withLock {
                    videoSendWindow.reset()
                    videoConfigurationGate.reset()
                }
                onVideoChannelChanged?(false)
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
        guard let peer, packet.type == .control else { peer?.cancel(); return }
        let message: ControlPacket
        do { message = try AfiControlCodec.decode(packet.payload) }
        catch let AfiControlError.incompatibleVersion(version) {
            send(.incompatibleVersion(expected: AfiProtocol.version), to: peer)
            SkeldriLogger.network.warning("Rejected Afi protocol version \(version)")
            peer.cancel()
            return
        } catch {
            peer.cancel()
            return
        }

        if case let .hello(_, channel, _, sessionID) = message {
            switch channel {
            case .control:
                control?.cancel()
                authorized = false
                controlSessionID = sessionID
                if let videoSessionID, videoSessionID != sessionID {
                    video?.cancel()
                    video = nil
                    self.videoSessionID = nil
                }
                control = peer
                pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
                onConnectionChanged?(true)
                onControlPacket?(message)
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
                onVideoChannelChanged?(true)
            }
        } else if peer === control, authorized {
            if case let .videoAcknowledgement(streamID, sequence, requiresKeyframe) = message {
                videoFlowLock.withLock { videoSendWindow.acknowledge(streamID: streamID, through: sequence) }
                if requiresKeyframe { onVideoRecoveryRequested?() }
            } else if case let .inputMode(mode) = message {
                onInputModeChanged?(mode)
            } else if case let .trackpad(event) = message {
                onTrackpadEvent?(event)
            } else {
                onControlPacket?(message)
            }
        }
    }

    private func send(_ packet: ControlPacket, to peer: PeerConnection) {
        if let data = try? AfiControlCodec.encode(packet) {
            peer.send(PacketFramer.frame(type: .control, payload: data))
        }
    }


    private func beginAuthorizationTimeout(for sessionID: UUID) {
        authorizationGeneration += 1
        let generation = authorizationGeneration
        queue.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, generation == authorizationGeneration,
                  controlSessionID == sessionID, !authorized else { return }
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
