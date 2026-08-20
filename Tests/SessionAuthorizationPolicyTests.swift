import Foundation
import Testing

struct SessionAuthorizationPolicyTests {
    @Test func videoChannelMustBelongToControlSession() {
        let session = UUID()
        #expect(SessionAuthorizationPolicy.acceptsVideo(sessionID: session, controlSessionID: nil))
        #expect(SessionAuthorizationPolicy.acceptsVideo(sessionID: session, controlSessionID: session))
        #expect(!SessionAuthorizationPolicy.acceptsVideo(sessionID: UUID(), controlSessionID: session))
    }

    @Test func transmissionRequiresApprovalAndMatchingChannels() {
        let session = UUID()
        #expect(!SessionAuthorizationPolicy.mayTransmit(
            authorized: false, controlSessionID: session, videoSessionID: session
        ))
        #expect(!SessionAuthorizationPolicy.mayTransmit(
            authorized: true, controlSessionID: session, videoSessionID: UUID()
        ))
        #expect(SessionAuthorizationPolicy.mayTransmit(
            authorized: true, controlSessionID: session, videoSessionID: session
        ))
    }
}
