import Foundation

/// Display metadata published by the Mac authority.
struct DisplayDescriptor: Codable, Sendable, Equatable, Identifiable {
    let id: UInt32
    let name: String
    let width: Int
    let height: Int

    var aspectRatio: Double { height > 0 ? Double(width) / Double(height) : 1 }
}

