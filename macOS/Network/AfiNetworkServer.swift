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

    private let queue = DispatchQueue(label: "Skeldri.network.afi")
    private var listener: NWListener?
    private var pendingPeers: [ObjectIdentifier: PeerConnection] = [:]
    private var control: PeerConnection?
    private var video: PeerConnection?
    private let videoFlowLock = NSLock()
    private var videoSendWindow = VideoSendWindow(maximumOutstandingFrames: 2)
    private var videoConfigurationGate = VideoConfigurationGate()
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

    func sendControl(_ packet: ControlPacket) {
        guard let data = try? AfiControlCodec.encode(packet) else { return }
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

    func sendVideoFrame(_ accessUnit: Data, header: VideoFrameHeader) -> Bool {
        guard let video,
              videoFlowLock.withLock({ videoSendWindow.reserve(streamID: header.streamID, sequence: header.sequence) }),
              let data = try? VideoEnvelope.encode(header: header, accessUnit: accessUnit) else { return false }
        video.send(PacketFramer.frame(type: .videoFrame, payload: data))
        return true
    }

    private func accept(_ connection: NWConnection) {
        let peer = PeerConnection(connection: connection, maximumPayload: PacketFramer.controlLimit)
        let identifier = ObjectIdentifier(peer)
        pendingPeers[identifier] = peer
        peer.onPacket = { [weak self, weak peer] packet in self?.classifyOrHandle(peer: peer, packet: packet) }
        peer.onStopped = { [weak self, weak peer] in
            guard let self, let peer else { return }
            pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
            if control === peer {
                control = nil
                onInputModeChanged?(.drawing)
                onConnectionChanged?(false)
            }
            if video === peer {
                video = nil
                videoFlowLock.withLock {
                    videoSendWindow.reset()
                    videoConfigurationGate.reset()
                }
                onVideoChannelChanged?(false)
            }
        }
        peer.start(queue: queue)
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

        if case let .hello(_, channel, _) = message {
            switch channel {
            case .control:
                control?.cancel()
                control = peer
                pendingPeers.removeValue(forKey: ObjectIdentifier(peer))
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
                onVideoChannelChanged?(true)
            }
        } else if peer === control {
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
}
