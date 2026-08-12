import CoreGraphics
import Foundation
import Testing

struct DrawingViewportTests {
    private let viewport = CGSize(width: 1000, height: 800)

    @Test func startsUnmagnifiedAndCentred() {
        let value = DrawingViewport()
        #expect(value.scale == 1)
        #expect(value.offset == .zero)
        #expect(!value.isMagnified)
    }

    @Test func successivePinchUpdatesCompose() {
        var value = DrawingViewport()
        value.magnify(by: 1.5, in: viewport)
        value.magnify(by: 2, in: viewport)
        #expect(value.scale == 3)
        #expect(value.isMagnified)
    }

    @Test func scaleIsBoundedAtBothEnds() {
        var value = DrawingViewport()
        value.magnify(by: 100, in: viewport)
        #expect(value.scale == DrawingViewport.maximumScale)

        value.magnify(by: 0.0001, in: viewport)
        #expect(value.scale == DrawingViewport.minimumScale)
    }

    @Test func pinchingBackOutSnapsCleanRatherThanLeavingDrift() {
        var value = DrawingViewport()
        value.magnify(by: 3, in: viewport)
        value.pan(by: CGPoint(x: 200, y: 200), in: viewport)

        // Just above 1 is a user who has finished zooming out.
        value.magnify(by: 1.01 / 3, in: viewport)

        #expect(value.scale == 1)
        #expect(value.offset == .zero)
        #expect(!value.isMagnified)
    }

    @Test func panningIsBoundedToContentThatActuallyExists() {
        var value = DrawingViewport()
        value.magnify(by: 2, in: viewport)

        value.pan(by: CGPoint(x: 10_000, y: 10_000), in: viewport)
        // A centre-anchored 2x exposes half the width and height beyond the edge.
        #expect(value.offset == CGPoint(x: 500, y: 400))

        value.pan(by: CGPoint(x: -100_000, y: -100_000), in: viewport)
        #expect(value.offset == CGPoint(x: -500, y: -400))
    }

    @Test func panningDoesNothingWhileUnmagnified() {
        var value = DrawingViewport()
        value.pan(by: CGPoint(x: 250, y: 250), in: viewport)
        #expect(value.offset == .zero)
    }

    @Test func zoomingOutRecentresProportionallyInsteadOfStranding() {
        var value = DrawingViewport()
        value.magnify(by: 4, in: viewport)
        value.pan(by: CGPoint(x: 10_000, y: 0), in: viewport)
        #expect(value.offset.x == 1500)

        // Halving the scale must not leave the offset outside the new bounds.
        value.magnify(by: 0.5, in: viewport)
        #expect(value.scale == 2)
        #expect(value.offset.x == 500)
    }

    @Test func nonFiniteGestureInputIsIgnored() {
        var value = DrawingViewport()
        value.magnify(by: 2, in: viewport)
        let before = value

        value.magnify(by: CGFloat.nan, in: viewport)
        value.magnify(by: CGFloat.infinity, in: viewport)
        value.pan(by: CGPoint(x: CGFloat.nan, y: 0), in: viewport)
        #expect(value == before)
    }

    @Test func resetReturnsToTheUnzoomedSurface() {
        var value = DrawingViewport()
        value.magnify(by: 3, in: viewport)
        value.pan(by: CGPoint(x: 100, y: 100), in: viewport)
        value.reset()
        #expect(value.scale == 1)
        #expect(value.offset == .zero)
    }
}
