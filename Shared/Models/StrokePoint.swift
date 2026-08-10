import Foundation

/// A sample in the shared top-left-origin normalized coordinate space.
struct StrokePoint: Codable, Sendable, Equatable {
    let x: Float
    let y: Float
    let timestamp: Double
    let pressure: Float?

    /// Returns a clamped sample, protecting renderers from malformed peers.
    var sanitized: StrokePoint {
        StrokePoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1), timestamp: timestamp,
                    pressure: pressure.map { min(max($0, 0), 1) })
    }
}

