import Foundation
import Testing

struct QuickColorPaletteTests {
    @Test func standardPaletteOffersExactlyThreeSlots() {
        #expect(QuickColorPalette.standard.colors.count == QuickColorPalette.slotCount)
    }

    @Test func updatingASlotLeavesTheOthersAlone() {
        var palette = QuickColorPalette.standard
        let blue = QuickColor(red: 0, green: 0.4, blue: 1)

        palette.update(blue, at: 1)

        #expect(palette.color(at: 1) == blue)
        #expect(palette.color(at: 0) == QuickColorPalette.standard.color(at: 0))
        #expect(palette.color(at: 2) == QuickColorPalette.standard.color(at: 2))
    }

    @Test func outOfRangeSlotsAreIgnoredRatherThanCrashing() {
        var palette = QuickColorPalette.standard
        let before = palette

        palette.update(QuickColor(red: 1, green: 1, blue: 1), at: -1)
        palette.update(QuickColor(red: 1, green: 1, blue: 1), at: QuickColorPalette.slotCount)

        #expect(palette == before)
        #expect(palette.color(at: -1) == nil)
        #expect(palette.color(at: QuickColorPalette.slotCount) == nil)
    }

    @Test func componentsAreClampedToTheVisibleRange() {
        let color = QuickColor(red: 4, green: -2, blue: 0.5)
        #expect(color == QuickColor(red: 1, green: 0, blue: 0.5))
    }

    @Test func aTruncatedStoredPaletteIsRefilledToKeepTheToolbarShape() throws {
        let stored = try JSONEncoder().encode(QuickColorPalette(colors: [
            QuickColor(red: 0.1, green: 0.2, blue: 0.3)
        ]))
        let restored = try JSONDecoder().decode(QuickColorPalette.self, from: stored)

        #expect(restored.colors.count == QuickColorPalette.slotCount)
        #expect(restored.color(at: 0) == QuickColor(red: 0.1, green: 0.2, blue: 0.3))
        #expect(restored.color(at: 2) == QuickColorPalette.standard.color(at: 2))
    }

    @Test func anOverlongStoredPaletteIsTruncated() throws {
        let many = (0..<10).map { QuickColor(red: Float($0) / 10, green: 0, blue: 0) }
        let restored = try JSONDecoder().decode(
            QuickColorPalette.self, from: try JSONEncoder().encode(QuickColorPalette(colors: many))
        )
        #expect(restored.colors.count == QuickColorPalette.slotCount)
    }

    @Test func outOfRangeStoredComponentsCannotProduceAnInvalidStroke() throws {
        // A hand-edited or corrupted preference file is untrusted input.
        let data = Data(#"{"colors":[{"red":9.5,"green":-3,"blue":0.5}]}"#.utf8)

        let restored = try JSONDecoder().decode(QuickColorPalette.self, from: data)
        let first = try #require(restored.color(at: 0))

        #expect(first == QuickColor(red: 1, green: 0, blue: 0.5))
    }

    @Test func paletteSurvivesARoundTrip() throws {
        var palette = QuickColorPalette.standard
        palette.update(QuickColor(red: 0.25, green: 0.5, blue: 0.75), at: 2)

        let restored = try JSONDecoder().decode(
            QuickColorPalette.self, from: try JSONEncoder().encode(palette)
        )
        #expect(restored == palette)
    }
}
