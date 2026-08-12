import Foundation

/// Capture/encoder policy selected by client capability, independent of transport.
struct VideoStreamingProfile: Sendable, Equatable {
    let maximumDimension: Int
    let framesPerSecond: Int
    let averageBitRate: Int

    static let modern = VideoStreamingProfile(maximumDimension: 1_600, framesPerSecond: 30,
                                              averageBitRate: 4_000_000)
    static let legacyAfi = VideoStreamingProfile(maximumDimension: 1_024, framesPerSecond: 24,
                                                 averageBitRate: 2_000_000)
}
