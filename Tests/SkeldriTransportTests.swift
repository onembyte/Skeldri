import Network
import Testing

struct SkeldriTransportTests {
    /// Nothing in Skeldri sends periodic traffic on an idle session, so keepalive
    /// is the only thing that reaps a peer which vanished without closing. A
    /// regression here is invisible until a device is powered off mid-session.
    @Test func tcpParametersEnableKeepaliveSoDeadPeersAreReaped() throws {
        let parameters = SkeldriTransport.tcpParameters()
        let tcp = try #require(parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options)

        #expect(tcp.enableKeepalive)
        #expect(tcp.keepaliveIdle == SkeldriTransport.keepaliveIdleSeconds)
        #expect(tcp.keepaliveInterval == SkeldriTransport.keepaliveIntervalSeconds)
        #expect(tcp.keepaliveCount == SkeldriTransport.keepaliveProbeCount)
    }

    @Test func detectionStaysInsideAUsableWindow() {
        let worstCase = SkeldriTransport.keepaliveIdleSeconds
            + SkeldriTransport.keepaliveIntervalSeconds * SkeldriTransport.keepaliveProbeCount

        // Long enough to ride out a brief Wi-Fi stall, short enough that the
        // owner is not left looking at a phantom connection.
        #expect(worstCase >= 15)
        #expect(worstCase <= 60)
    }

    @Test func listenerParametersStillAllowLocalEndpointReuse() {
        #expect(SkeldriTransport.tcpParameters().allowLocalEndpointReuse)
    }
}
