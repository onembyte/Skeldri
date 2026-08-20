import Foundation

/// Mutually exclusive iPad interaction surfaces. Drawing and pointer control
/// never observe the same touch sequence.
enum SkeldriInputMode: String, Codable, Sendable, Equatable {
    case drawing
    case trackpad
    /// Read-only, locally navigable video surface. This mode never authorizes
    /// drawing or pointer packets.
    case lecture
}
