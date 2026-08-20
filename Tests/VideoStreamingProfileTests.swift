import Testing

struct VideoStreamingProfileTests {
    @Test func legacyProfileReducesEveryExpensiveDimension() {
        #expect(VideoStreamingProfile.legacyAfi.maximumDimension < VideoStreamingProfile.modern.maximumDimension)
        #expect(VideoStreamingProfile.legacyAfi.framesPerSecond < VideoStreamingProfile.modern.framesPerSecond)
        #expect(VideoStreamingProfile.legacyAfi.averageBitRate < VideoStreamingProfile.modern.averageBitRate)
        #expect(VideoStreamingProfile.legacyAfi == .init(maximumDimension: 1_024,
                                                        framesPerSecond: 24,
                                                        averageBitRate: 2_000_000))
    }
}
