import Foundation

/// Portable visual attributes for a stroke; widths are relative to the shortest display dimension.
struct StrokeStyle: Codable, Sendable, Equatable {
    let tool: DrawingTool
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
    let normalizedWidth: Float

    static let defaultPen = StrokeStyle(tool: .pen, red: 1, green: 0, blue: 0, alpha: 1, normalizedWidth: 0.005)
}

