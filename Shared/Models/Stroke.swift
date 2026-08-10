import Foundation

/// An independently addressable vector stroke shared by both peers.
struct Stroke: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let style: StrokeStyle
    var points: [StrokePoint]
}

