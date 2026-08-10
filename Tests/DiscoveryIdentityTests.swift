import Testing

struct DiscoveryIdentityTests {
    @Test func stableIdentityCollapsesRenamedAdvertisements() {
        #expect(DiscoveryIdentity.key(stableID: "mac-1", serviceName: "MacBook Air") ==
                DiscoveryIdentity.key(stableID: "mac-1", serviceName: "MacBook Air (2)"))
    }

    @Test func differentStableIdentitiesRemainDistinct() {
        #expect(DiscoveryIdentity.key(stableID: "mac-1", serviceName: "MacBook Air") !=
                DiscoveryIdentity.key(stableID: "mac-2", serviceName: "MacBook Air"))
    }

    @Test func legacyBonjourSuffixIsCollapsed() {
        #expect(DiscoveryIdentity.key(stableID: nil, serviceName: "MacBook Air") ==
                DiscoveryIdentity.key(stableID: nil, serviceName: "MacBook Air (3)"))
        #expect(DiscoveryIdentity.canonicalLegacyName("Studio (Office)") == "Studio (Office)")
    }
}
