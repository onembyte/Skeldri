import Foundation

/// A rendered drawing instrument. Erasing is an interaction mode and therefore is not a stroke tool.
enum DrawingTool: String, Codable, Sendable, CaseIterable {
    case pen
    case highlighter
}

