import Foundation

/// One user-configurable quick colour. Components are stored in the same
/// normalized form `StrokeStyle` transmits, so a slot round-trips without a
/// colour-space conversion in between.
struct QuickColor: Codable, Sendable, Equatable {
    var red: Float
    var green: Float
    var blue: Float

    init(red: Float, green: Float, blue: Float) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Restored preferences are untrusted input: a non-finite or out-of-range
        // component would otherwise produce an invisible or invalid stroke.
        self.init(
            red: try container.decode(Float.self, forKey: .red).sanitized,
            green: try container.decode(Float.self, forKey: .green).sanitized,
            blue: try container.decode(Float.self, forKey: .blue).sanitized
        )
    }
}

/// The three quick colours offered beside the colour picker.
///
/// The picker edits whichever slot is selected, so choosing a colour both draws
/// with it and reconfigures that slot.
struct QuickColorPalette: Codable, Sendable, Equatable {
    static let slotCount = 3
    static let standard = QuickColorPalette(colors: [
        QuickColor(red: 0.90, green: 0.22, blue: 0.21),
        QuickColor(red: 0.20, green: 0.78, blue: 0.35),
        QuickColor(red: 1.00, green: 0.58, blue: 0.00)
    ])

    private(set) var colors: [QuickColor]

    init(colors: [QuickColor]) {
        // Always exactly `slotCount` entries: a short or padded array from an
        // older or corrupted preference must not change the toolbar's shape.
        var resolved = Array(colors.prefix(Self.slotCount))
        if resolved.count < Self.slotCount {
            let fallback = Self.fallbackColors
            resolved.append(contentsOf: fallback[resolved.count..<Self.slotCount])
        }
        self.colors = resolved
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(colors: try container.decode([QuickColor].self, forKey: .colors))
    }

    func color(at index: Int) -> QuickColor? {
        colors.indices.contains(index) ? colors[index] : nil
    }

    mutating func update(_ color: QuickColor, at index: Int) {
        guard colors.indices.contains(index) else { return }
        colors[index] = color
    }

    /// Referenced during `init`, so it cannot be `standard` itself.
    private static let fallbackColors = [
        QuickColor(red: 0.90, green: 0.22, blue: 0.21),
        QuickColor(red: 0.20, green: 0.78, blue: 0.35),
        QuickColor(red: 1.00, green: 0.58, blue: 0.00)
    ]
}

private extension Float {
    var sanitized: Float { isFinite ? self : 0 }

    func clamped(to range: ClosedRange<Float>) -> Float {
        guard isFinite else { return range.lowerBound }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
