import Foundation

/// Mutually exclusive iPad interaction surfaces. Drawing and pointer control
/// never observe the same touch sequence.
enum DrawPadInputMode: String, Codable, Sendable, Equatable {
    case drawing
    case trackpad
}
