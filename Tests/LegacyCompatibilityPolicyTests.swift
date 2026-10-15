import Testing

struct LegacyCompatibilityPolicyTests {
    /// Nothing extra listens on the network unless the Mac's owner opts in.
    @Test func olderIPadsAreOffByDefault() {
        #expect(!LegacyCompatibilityPolicy.allowsOlderIPadsByDefault)
        #expect(LegacyCompatibilityPolicy.action(allowsOlderIPads: false, isListening: false) == .none)
    }

    @Test func allowingOlderIPadsStartsTheListenerOnce() {
        #expect(LegacyCompatibilityPolicy.action(allowsOlderIPads: true, isListening: false) == .start)
        #expect(LegacyCompatibilityPolicy.action(allowsOlderIPads: true, isListening: true) == .none)
    }

    @Test func disallowingStopsARunningListener() {
        #expect(LegacyCompatibilityPolicy.action(allowsOlderIPads: false, isListening: true) == .stop)
    }
}
