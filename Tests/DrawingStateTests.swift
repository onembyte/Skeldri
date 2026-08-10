import Foundation
import Testing

@MainActor
struct DrawingStateTests {
    @Test func clearRemovesEveryCompletedAndActiveStroke() {
        let state = DrawingState()
        let firstID = UUID()
        let secondID = UUID()
        let point = StrokePoint(x: 0.25, y: 0.75, timestamp: 0, pressure: nil)

        state.begin(id: firstID, style: .defaultPen, point: point)
        state.finish(id: firstID)
        state.begin(id: secondID, style: .defaultPen, point: point)

        state.clear()

        #expect(state.strokes.isEmpty)
        #expect(state.undo() == nil)
    }
}
