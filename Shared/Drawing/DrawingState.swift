import Foundation

/// Deterministic mutation boundary for the complete annotation canvas.
@MainActor
final class DrawingState: ObservableObject {
    @Published private(set) var strokes: [Stroke] = []

    func begin(id: UUID, style: StrokeStyle, point: StrokePoint) {
        guard !strokes.contains(where: { $0.id == id }) else { return }
        strokes.append(Stroke(id: id, style: style, points: [point.sanitized]))
    }

    func append(id: UUID, points: [StrokePoint]) {
        guard let index = strokes.firstIndex(where: { $0.id == id }) else { return }
        strokes[index].points.append(contentsOf: points.map(\.sanitized))
    }

    func finish(id: UUID) { /* Identity and order are already final. */ }

    func delete(ids: [UUID]) { strokes.removeAll { ids.contains($0.id) } }

    @discardableResult func undo() -> UUID? {
        guard let stroke = strokes.popLast() else { return nil }
        return stroke.id
    }

    func clear() { strokes.removeAll(keepingCapacity: true) }
    func replace(with snapshot: [Stroke]) { strokes = snapshot }
}

